# frozen_string_literal: true

module CordKit
  # Base class for CordKit plugins.
  #
  # The simplest command needs only a description and a block:
  #
  #   class Ping < CordKit::Plugin
  #     command :ping, "Replies with pong" do |ctx|
  #       ctx.respond "Pong!"
  #     end
  #   end
  class Plugin
    # A component, modal or autocomplete handler declared in a plugin.
    ComponentDefinition = Struct.new(:type, :matcher, :route, :block, keyword_init: true) do
      def route?
        !route.nil?
      end
    end

    # A raw discordrb event handler.
    EventDefinition = Struct.new(:event_name, :filters, :block, keyword_init: true)

    # An autocomplete handler attached to a command, subcommand or group.
    AutocompleteDefinition = Struct.new(:command_name, :option_name, :group, :subcommand, :block, keyword_init: true)

    # An error handler registered with {Plugin.rescue_from}.
    RescueDefinition = Struct.new(:error_class, :block, keyword_init: true)

    # Every interaction type a plugin may register.
    COMPONENT_TYPES = %i[any button select string_select user_select role_select mentionable_select channel_select
                         modal].freeze

    # Interaction types that behave like select menus.
    SELECT_TYPES = %i[select string_select user_select role_select mentionable_select channel_select].freeze

    class << self
      # @return [Array<Class>]
      def registry
        @registry ||= []
      end

      # @return [Array<CordKit::Command>]
      attr_reader :commands

      # @return [Array<CordKit::Plugin::ComponentDefinition>]
      attr_reader :component_definitions

      # @return [Array<CordKit::Plugin::AutocompleteDefinition>]
      attr_reader :autocomplete_definitions

      # @return [Array<CordKit::Plugin::EventDefinition>]
      attr_reader :event_definitions

      # @return [Array<CordKit::Check>]
      attr_reader :checks

      # @return [Array<Proc>]
      attr_reader :before_hooks

      # @return [Array<Proc>]
      attr_reader :after_hooks

      # @return [Array<CordKit::Plugin::RescueDefinition>]
      attr_reader :rescue_handlers

      # @return [CordKit::Cooldown, nil]
      attr_reader :cooldown_setting

      # @return [Array<Symbol>]
      attr_reader :dependencies

      # Initializes per-subclass state and records the subclass in {.registry}.
      # @param subclass [Class<CordKit::Plugin>]
      def inherited(subclass)
        super
        subclass.instance_variable_set(:@commands, [])
        subclass.instance_variable_set(:@component_definitions, [])
        subclass.instance_variable_set(:@autocomplete_definitions, [])
        subclass.instance_variable_set(:@event_definitions, [])
        subclass.instance_variable_set(:@checks, [])
        subclass.instance_variable_set(:@before_hooks, [])
        subclass.instance_variable_set(:@after_hooks, [])
        subclass.instance_variable_set(:@rescue_handlers, [])
        subclass.instance_variable_set(:@cooldown_setting, nil)
        subclass.instance_variable_set(:@dependencies, [])
        subclass.instance_variable_set(:@plugin_name, nil)
        subclass.instance_variable_set(:@description, nil)
        Plugin.registry << subclass
      end

      # Sets or returns the plugin name used in routes and custom IDs.
      # @param value [Symbol, String, nil]
      # @return [Symbol]
      def plugin_name(value = nil)
        if value
          unless value.to_s.match?(CustomId::NAME_PATTERN)
            raise InvalidPluginError, "Invalid plugin name #{value.to_s.inspect}"
          end

          @plugin_name = value.to_s.to_sym
        else
          @plugin_name ||= begin
            candidate = name.to_s.split("::").last.to_s
            candidate = candidate.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
            candidate = "plugin" if candidate.empty?
            candidate.to_sym
          end
        end
      end

      # Sets or returns the plugin description.
      # @param value [String, nil]
      # @return [String]
      def description(value = nil)
        if value
          @description = value.to_s
        else
          @description ||= ""
        end
      end

      # Declares other plugin names that must be loaded first.
      # @return [Array<Symbol>]
      def depends_on(*names)
        @dependencies.concat(names.flatten.map(&:to_sym))
        @dependencies
      end

      # Defines a chat input command.
      # @return [CordKit::Command]
      def command(name, description = nil, type: :chat_input, &block)
        add_command(name, description: description, type: type, &block)
      end

      # Defines a user context menu command.
      # @return [CordKit::Command]
      def user_command(name, description = nil, &)
        add_command(name, description: description, type: :user, &)
      end

      # Defines a message context menu command.
      # @return [CordKit::Command]
      def message_command(name, description = nil, &)
        add_command(name, description: description, type: :message, &)
      end

      # Defines a component handler. Symbol matchers are plugin routes, strings and
      # regexps match the raw custom ID.
      # @return [CordKit::Plugin::ComponentDefinition]
      def component(matcher, type: :any, &block)
        add_component(matcher, type: type, &block)
      end

      # Defines a button handler.
      # @return [CordKit::Plugin::ComponentDefinition]
      def button(matcher, &)
        add_component(matcher, type: :button, &)
      end

      # Defines a select menu handler.
      # @return [CordKit::Plugin::ComponentDefinition]
      def select(matcher, type: nil, &block)
        add_component(matcher, type: type || :select, &block)
      end

      # Defines a modal submission handler.
      # @return [CordKit::Plugin::ComponentDefinition]
      def modal(matcher, &)
        add_component(matcher, type: :modal, &)
      end

      # Defines an autocomplete handler for a command option.
      # @return [CordKit::Plugin::AutocompleteDefinition]
      def autocomplete(command_name, option_name = nil, group: nil, subcommand: nil, &block)
        raise ArgumentError, "An autocomplete block is required" unless block

        raise ArgumentError, "An autocomplete option name is required" unless option_name

        definition = AutocompleteDefinition.new(
          command_name: command_name.to_sym,
          option_name: option_name.to_sym,
          group: group&.to_sym,
          subcommand: subcommand&.to_sym,
          block: block
        )
        @autocomplete_definitions << definition
        definition
      end

      # Defines a raw discordrb event handler.
      # @return [CordKit::Plugin::EventDefinition]
      def on(event_name, **filters, &block)
        raise ArgumentError, "An event handler block is required" unless block

        definition = EventDefinition.new(event_name: event_name.to_sym, filters: filters, block: block)
        @event_definitions << definition
        definition
      end

      # Adds a plugin-wide check.
      # @return [CordKit::Check]
      def check(name = nil, message: nil, &block)
        @checks << Checks.custom(name: name, message: message, &block)
      end

      # Runs a block before every plugin handler.
      # @return [Proc]
      def before(&block)
        raise ArgumentError, "A before block is required" unless block

        @before_hooks << block
        block
      end

      # Runs a block after every plugin handler.
      # @return [Proc]
      def after(&block)
        raise ArgumentError, "An after block is required" unless block

        @after_hooks << block
        block
      end

      # Handles errors raised by this plugin.
      # @return [CordKit::Plugin::RescueDefinition]
      def rescue_from(error_class = StandardError, &block)
        raise ArgumentError, "A rescue block is required" unless block

        definition = RescueDefinition.new(error_class: error_class, block: block)
        @rescue_handlers << definition
        definition
      end

      # Adds a plugin-wide cooldown applied to every command.
      # @return [CordKit::Cooldown]
      def cooldown(seconds, per: :user, message: nil)
        @cooldown_setting = Cooldown.new(seconds, per: per, message: message)
      end

      # @return [Array<CordKit::Plugin::RescueDefinition>]
      def matching_rescues(error)
        rescue_handlers.select { |definition| error.is_a?(definition.error_class) }
      end

      private

      def add_command(name, description:, type:, &block)
        builder = CommandBuilder.new(name, description: description, type: type, plugin_class: self)
        if block
          if block.arity.zero?
            builder.instance_eval(&block)
          else
            builder.run(&block)
          end
        end
        command = builder.to_command
        @commands << command
        command
      end

      def add_component(matcher, type:, &block)
        raise ArgumentError, "A component handler block is required" unless block

        type = type.to_sym
        raise InvalidPluginError, "Unknown component type: #{type.inspect}" unless COMPONENT_TYPES.include?(type)

        route = nil
        matcher = case matcher
                  when Symbol
                    route = matcher.to_s
                    CustomId.normalize_name(route, "route").to_sym
                  when String, Regexp
                    matcher
                  else
                    raise InvalidPluginError, "Component matcher must be a Symbol, String or Regexp."
                  end

        definition = ComponentDefinition.new(type: type, matcher: matcher, route: route, block: block)
        @component_definitions << definition
        definition
      end
    end

    # @return [CordKit::Runtime]
    attr_reader :runtime

    # @return [Discordrb::Bot]
    attr_reader :bot

    # @return [CordKit::Configuration]
    attr_reader :config

    def initialize(runtime)
      @runtime = runtime
      @bot = runtime.bot
      @config = runtime.config
    end

    # @return [Symbol]
    def plugin_name
      self.class.plugin_name
    end

    # @return [Logger, Discordrb::Logger]
    def logger
      runtime.logger
    end

    # @return [CordKit::StateStore]
    def state_store
      runtime.state_store
    end

    # Called after the plugin is registered.
    def on_load; end

    # Called when the bot becomes ready. May be called after reconnects.
    def on_ready; end

    # Called when the plugin is unloaded.
    def on_unload; end
  end
end
