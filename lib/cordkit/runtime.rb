# frozen_string_literal: true

module CordKit
  # The runtime connects a discordrb bot, plugins, commands and interactions.
  class Runtime
    # Bookkeeping for a loaded plugin.
    PluginRecord = Struct.new(:plugin_class, :instance, :application_commands, :event_handlers, keyword_init: true)

    # @return [Discordrb::Bot]
    attr_reader :bot

    # @return [CordKit::Configuration]
    attr_reader :config

    # @return [Hash<Symbol, CordKit::Runtime::PluginRecord>]
    attr_reader :plugins

    # @return [CordKit::CommandRegistry]
    attr_reader :command_registry

    # @return [CordKit::Router]
    attr_reader :router

    # @return [CordKit::StateStore]
    attr_reader :state_store

    # @return [Logger, Discordrb::Logger]
    attr_reader :logger

    def initialize(bot, **options, &block)
      @bot = bot
      @config = Configuration.new
      apply_options(options)
      block&.call(@config)
      @logger = @config.logger || Discordrb::LOGGER
      @plugins = {}
      @command_registry = CommandRegistry.new
      @router = Router.new(self)
      @state_store = @config.state_store || StateStore::Memory.new(default_ttl: @config.state_ttl)
      @global_handlers = []
      @sync_mutex = Mutex.new
      @synced = false
      @syncing = false
      @stopped = false
      install_global_handlers
    end

    # Registers and loads a plugin class.
    #
    # @param plugin_class [Class<CordKit::Plugin>]
    # @return [CordKit::Plugin] The plugin instance.
    def register_plugin(plugin_class)
      unless plugin_class.is_a?(Class) && plugin_class <= Plugin
        raise InvalidPluginError, "#{plugin_class.inspect} is not a CordKit::Plugin subclass."
      end

      plugin_name = plugin_class.plugin_name
      return @plugins[plugin_name].instance if @plugins.key?(plugin_name)

      load_dependencies(plugin_class)
      plugin_class.commands.each do |command|
        command.validate! if @config.validate_on_load
        @command_registry.validate!(command)
      end

      instance = plugin_class.new(self)
      record = PluginRecord.new(
        plugin_class: plugin_class,
        instance: instance,
        application_commands: [],
        event_handlers: []
      )

      begin
        plugin_class.component_definitions.each { |definition| @router.register_component(instance, definition) }
        plugin_class.autocomplete_definitions.each { |definition| @router.register_autocomplete(instance, definition) }

        plugin_class.commands.each do |command|
          @command_registry.add(command)
          record.application_commands << command.name
          bind_application_command(instance, command)
        end

        plugin_class.event_definitions.each do |definition|
          record.event_handlers << bind_event(instance, definition)
        end
      rescue StandardError
        @router.remove_plugin(plugin_name)
        @command_registry.remove_plugin(plugin_name)
        record.application_commands.each { |name| @bot.remove_application_command_handler(name) }
        record.event_handlers.each { |handler| @bot.remove_handler(handler) }
        raise
      end

      @plugins[plugin_name] = record
      safe_plugin_hook(instance, :on_load)
      instance
    end
    alias plugin register_plugin
    alias load_plugin register_plugin

    # Unloads a plugin.
    # @param plugin_name [Symbol, String]
    # @return [Boolean]
    def unload_plugin(plugin_name)
      record = @plugins.delete(plugin_name.to_sym)
      return false unless record

      safe_plugin_hook(record.instance, :on_unload)
      record.application_commands.each { |name| @bot.remove_application_command_handler(name) }
      record.event_handlers.each { |handler| @bot.remove_handler(handler) }
      @router.remove_plugin(plugin_name)
      @command_registry.remove_plugin(plugin_name)
      true
    end
    alias unregister_plugin unload_plugin

    # Reloads a plugin class.
    # @return [CordKit::Plugin]
    def reload_plugin(plugin_class)
      unload_plugin(plugin_class.plugin_name)
      register_plugin(plugin_class)
    end

    # Synchronizes commands with Discord.
    # @param scope [Symbol, nil]
    # @param mode [Symbol, nil]
    # @param guild_ids [Array<Integer>, :all, nil]
    # @return [Object]
    def sync_commands!(scope: nil, mode: nil, guild_ids: nil)
      shard_id = bot.shard_key&.first
      if shard_id && shard_id != 0
        logger.debug("Skipping command sync on shard #{shard_id}.")
        return nil
      end

      result = synchronizer.sync!(scope: scope, mode: mode, guild_ids: guild_ids)
      @sync_mutex.synchronize { @synced = true }
      logger.info("CordKit synchronized #{@command_registry.size} command(s).")
      result
    rescue StandardError => e
      logger.error("CordKit command sync failed: #{e.class}: #{e.message}")
      raise
    ensure
      @sync_mutex.synchronize { @syncing = false }
    end

    # Starts command synchronization in a background thread.
    # @return [Thread]
    def sync_commands_async(**options)
      Thread.new do
        Thread.current.report_on_exception = false
        sync_commands!(**options)
      rescue StandardError
        # sync_commands! already logs the failure.
      end
    end

    # @return [Boolean]
    def synced?
      @sync_mutex.synchronize { @synced }
    end

    # Stops the runtime, unloads plugins and removes global handlers.
    def stop
      return if @stopped

      @stopped = true
      @plugins.each_key { |plugin_name| unload_plugin(plugin_name) }
      @global_handlers.each { |handler| @bot.remove_handler(handler) }
      @global_handlers.clear
    end

    # @return [Class<CordKit::Synchronizer>]
    def synchronizer
      @synchronizer ||= Synchronizer.new(self)
    end

    private

    def apply_options(options)
      options.each do |key, value|
        setter = "#{key}="
        unless @config.respond_to?(setter)
          raise ConfigurationError, "Unknown CordKit configuration option: #{key.inspect}"
        end

        @config.public_send(setter, value)
      end
    end

    def install_global_handlers
      @global_handlers << @bot.ready { |_event| handle_ready }
      @global_handlers << @bot.button { |event| dispatch_component(:button, event) }
      @global_handlers << @bot.string_select { |event| dispatch_component(:string_select, event) }
      @global_handlers << @bot.user_select { |event| dispatch_component(:user_select, event) }
      @global_handlers << @bot.role_select { |event| dispatch_component(:role_select, event) }
      @global_handlers << @bot.mentionable_select { |event| dispatch_component(:mentionable_select, event) }
      @global_handlers << @bot.channel_select { |event| dispatch_component(:channel_select, event) }
      @global_handlers << @bot.modal_submit { |event| dispatch_component(:modal, event) }
      @global_handlers << @bot.autocomplete { |event| dispatch_autocomplete(event) }
    end

    def handle_ready
      @plugins.each_value do |record|
        safe_plugin_hook(record.instance, :on_ready)
      end

      return unless @config.sync?

      @sync_mutex.synchronize do
        return if @syncing || @synced

        @syncing = true
      end

      sync_commands_async
    end

    def load_dependencies(plugin_class)
      plugin_class.dependencies.each do |dependency_name|
        if dependency_name == plugin_class.plugin_name
          raise InvalidPluginError, "Plugin #{plugin_class.plugin_name.inspect} cannot depend on itself."
        end
        next if @plugins.key?(dependency_name)

        dependency = Plugin.registry.find { |candidate| candidate.plugin_name == dependency_name }
        unless dependency
          raise InvalidPluginError,
                "Plugin #{plugin_class.plugin_name.inspect} depends on #{dependency_name.inspect}, " \
                "which is not defined."
        end

        register_plugin(dependency)
      end
    end

    def bind_application_command(instance, command)
      handler = @bot.application_command(command.name) do |event|
        if command.handler
          dispatch_command(instance, command, event)
        else
          respond_unknown_subcommand(event)
        end
      end

      command.subcommands.each do |name, subcommand|
        handler.subcommand(name) { |event| dispatch_command(instance, subcommand, event) }
      end

      command.subcommand_groups.each do |group_name, group|
        handler.group(group_name) do |builder|
          group.subcommands.each do |name, subcommand|
            builder.subcommand(name) { |event| dispatch_command(instance, subcommand, event) }
          end
        end
      end

      handler
    end

    def bind_event(instance, definition)
      event_name = definition.event_name
      raise InvalidPluginError, "Unknown discordrb event: #{event_name.inspect}" unless @bot.respond_to?(event_name)

      @bot.public_send(event_name, definition.filters) do |event|
        begin
          instance.instance_exec(event, &definition.block)
        rescue StandardError => e
          log_error(e, plugin: instance)
        end
      end
    end

    def dispatch_command(instance, command, event)
      context = Context.new(runtime: self, event: event, plugin: instance, command: command)
      execute_handler(instance, context, command: command) do
        instance.instance_exec(context, &command.handler)
      end
    end

    def dispatch_component(type, event)
      result = @router.find_component(type, event.custom_id)
      return respond_unknown_interaction(event) unless result

      handler, captures, parsed = result
      context_class = type == :modal ? ModalContext : ComponentContext
      context = context_class.new(
        runtime: self,
        event: event,
        plugin: handler.plugin,
        params: { captures: captures, parsed: parsed }
      )

      execute_handler(handler.plugin, context) do
        handler.plugin.instance_exec(context, *captures, &handler.block)
      end
    end

    def dispatch_autocomplete(event)
      command = @command_registry[event.command_name]
      return unless command

      leaf = resolve_leaf(command, event)
      return unless leaf

      record = @plugins[command.plugin_class.plugin_name]
      return unless record

      option = event.focused&.to_sym
      return unless option

      block = leaf.autocomplete_handlers[option] || command.autocomplete_handlers[option]
      plugin_instance = record.instance

      context = AutocompleteContext.new(runtime: self, event: event, plugin: plugin_instance, command: leaf)

      if block
        result = plugin_instance.instance_exec(context, &block)
        context.choices(result) if !context.responded? && (result.is_a?(Array) || result.is_a?(Hash))
      else
        handler = @router.find_autocomplete(event.command_name, event.subcommand_group, event.subcommand, option)
        if handler
          result = handler.plugin.instance_exec(context, &handler.block)
          context.choices(result) if !context.responded? && (result.is_a?(Array) || result.is_a?(Hash))
        else
          context.choices([])
        end
      end

      context.choices([]) unless context.responded?
    rescue StandardError => e
      log_error(e)
      begin
        context&.choices([])
      rescue StandardError
        nil
      end
    end

    def resolve_leaf(command, event)
      if event.subcommand_group
        command.subcommand_groups[event.subcommand_group]&.subcommands&.[](event.subcommand)
      elsif event.subcommand
        command.subcommands[event.subcommand]
      else
        command
      end
    end

    def execute_handler(instance, context, command: nil)
      before_ran = false
      watchdog = nil
      begin
        run_checks(instance, context, command)
        run_before_hooks(instance, context)
        before_ran = true
        watchdog = start_watchdog(context, command)
        yield
      rescue Halt
        nil
      rescue UserError => e
        safe_error_response(context, e.message, ephemeral: e.ephemeral)
      rescue CheckFailed, CooldownError => e
        safe_error_response(context, e.message, ephemeral: true)
      rescue StandardError => e
        handle_error(context, e, plugin: instance, command: command)
      ensure
        watchdog&.kill if watchdog&.alive?
        run_after_hooks(instance, context) if before_ran
      end
    end

    def run_checks(instance, context, command)
      checks = instance.class.checks + (command ? command.effective_checks : [])
      checks.each { |check| check.call(context) }

      cooldown = command&.effective_cooldown || instance.class.cooldown_setting
      return unless cooldown

      key = command ? "#{instance.plugin_name}:#{command.full_name}" : instance.plugin_name.to_s
      cooldown.check!(context, key)
    end

    def run_before_hooks(instance, context)
      instance.class.before_hooks.each { |hook| instance.instance_exec(context, &hook) }
    end

    def run_after_hooks(instance, context)
      instance.class.after_hooks.each { |hook| instance.instance_exec(context, &hook) }
    rescue StandardError => e
      handle_error(context, e, plugin: instance)
    end

    def start_watchdog(context, command)
      return context.defer if command&.effective_defer

      delay = config.auto_defer_after.to_f
      return nil unless delay.positive?

      Thread.new do
        Thread.current.report_on_exception = false
        sleep delay
        next if context.acknowledged?

        if context.is_a?(ComponentContext) && !context.is_a?(ModalContext)
          context.defer_update
        else
          context.defer
        end
      rescue StandardError => e
        logger.debug("CordKit auto-defer failed: #{e.class}: #{e.message}")
      end
    end

    def respond_unknown_subcommand(event)
      event.interaction.respond(content: "Unknown subcommand.", ephemeral: true)
    rescue StandardError => e
      log_error(e)
    end

    def respond_unknown_interaction(event)
      message = @config.unknown_interaction_message
      return unless message

      event.interaction.respond(content: message, ephemeral: true)
    rescue StandardError => e
      log_error(e)
    end

    def safe_error_response(context, message, ephemeral: true)
      return if context.responded?

      if context.deferred?
        context.edit(message)
      else
        context.respond(message, ephemeral: ephemeral)
      end
    rescue StandardError => e
      logger.debug("CordKit could not send an error response: #{e.class}: #{e.message}")
    end

    def handle_error(context, error, plugin: nil, command: nil)
      log_error(error, plugin: plugin, command: command)

      handled = false
      if plugin
        plugin.class.matching_rescues(error).each do |definition|
          result = plugin.instance_exec(context, error, &definition.block)
          safe_error_response(context, result) if result.is_a?(String) && !context.responded?
          handled = true if context.responded?
        end
      end

      if @config.on_error
        result = call_error_hook(context, error)
        safe_error_response(context, result) if result.is_a?(String) && !context.responded?
        handled = true if context.responded?
      end

      safe_error_response(context, @config.default_error_message) unless handled
    rescue StandardError => e
      logger.error("CordKit error handler failed: #{e.class}: #{e.message}")
    end

    def call_error_hook(context, error)
      return @config.on_error.call(context, error) if @config.on_error.arity >= 2

      @config.on_error.call(error)
    end

    def log_error(error, plugin: nil, command: nil)
      parts = ["CordKit error"]
      parts << "plugin=#{plugin.plugin_name}" if plugin
      parts << "command=#{command.full_name}" if command
      logger.error("#{parts.join(' ')}: #{error.class}: #{error.message}")
      logger.debug(error.backtrace.join("\n")) if error.backtrace
    end

    def safe_plugin_hook(instance, hook)
      instance.public_send(hook)
    rescue StandardError => e
      log_error(e, plugin: instance)
    end
  end
end
