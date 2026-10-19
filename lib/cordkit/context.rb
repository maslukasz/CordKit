# frozen_string_literal: true

require "forwardable"

module CordKit
  # Base context passed to commands, component handlers and autocomplete handlers.
  #
  # The most common methods are {#respond}, {#defer}, {#edit}, {#[]} and {#view}.
  class Context
    extend Forwardable

    # @return [CordKit::Runtime]
    attr_reader :runtime

    # @return [Discordrb::Events::InteractionCreateEvent]
    attr_reader :event

    # @return [CordKit::Plugin]
    attr_reader :plugin

    # @return [CordKit::Command, nil]
    attr_reader :command

    # @return [Hash<Symbol, Object>]
    attr_reader :options

    # @return [Hash]
    attr_reader :params

    def_delegators :@event, :user, :server, :server_id, :channel, :channel_id, :user_locale, :context
    def_delegators :interaction, :id, :token, :application_id, :application_permissions, :server_locale,
                   :max_attachment_size

    # @param runtime [CordKit::Runtime]
    # @param event [Discordrb::Events::InteractionCreateEvent]
    # @param plugin [CordKit::Plugin]
    # @param command [CordKit::Command, nil]
    # @param params [Hash]
    def initialize(runtime:, event:, plugin:, command: nil, params: {})
      @runtime = runtime
      @event = event
      @plugin = plugin
      @command = command
      @params = params
      @options = command ? command.normalize_options(event) : {}
      @response_mutex = Mutex.new
      @acknowledged = false
      @deferred = false
      @responded = false
      @created_at = monotonic_time
    end

    # @return [Discordrb::Interaction]
    def interaction
      event.interaction
    end

    # @return [Discordrb::Bot]
    def bot
      runtime.bot
    end

    # @return [CordKit::Configuration]
    def config
      runtime.config
    end

    # @return [Logger, Discordrb::Logger]
    def logger
      runtime.logger
    end

    # @return [CordKit::StateStore]
    def state_store
      runtime.state_store
    end

    # @return [Symbol]
    def plugin_name
      plugin.plugin_name
    end

    # @return [Discordrb::Server, nil]
    def guild
      server
    end

    # @return [Discordrb::Member, nil]
    def member
      user if user.respond_to?(:roles)
    end

    # @return [Discordrb::Member, nil]
    def bot_member
      return nil unless server

      @bot_member ||= server.member(bot.profile.id)
    rescue StandardError
      nil
    end

    # @return [Symbol, nil]
    def command_name
      event.command_name if event.respond_to?(:command_name)
    end

    # @return [Symbol, nil]
    def subcommand
      event.subcommand if event.respond_to?(:subcommand)
    end

    # @return [Symbol, nil]
    def subcommand_group
      event.subcommand_group if event.respond_to?(:subcommand_group)
    end

    # @return [Object, nil]
    def target
      event.target if event.respond_to?(:target)
    end

    # @param name [Symbol, String]
    # @return [Object, nil]
    def [](name)
      options[name.to_sym]
    end
    alias option []

    # @param name [Symbol, String]
    # @return [Object, nil]
    def fetch(name, default = nil, &)
      options.fetch(name.to_sym, default, &)
    end

    # @param name [Symbol, String]
    # @return [Boolean]
    def option?(name)
      options.key?(name.to_sym)
    end

    # Responds to the interaction. If this is the first response, it uses the
    # initial interaction response. If the interaction was deferred, it edits
    # the deferred response. Later calls become follow-up messages.
    #
    # @param content [String, nil]
    # @param kwargs [Hash] discordrb interaction response options.
    # @return [Object, nil]
    def respond(content = nil, **kwargs, &)
      kwargs = prepare_response(kwargs, &)
      kwargs[:content] = content unless content.nil?

      @response_mutex.synchronize do
        if !@acknowledged
          interaction.respond(**filter_kwargs(kwargs, :respond))
          @acknowledged = true
          @responded = true
        elsif @deferred && !@responded
          interaction.edit_response(**filter_kwargs(kwargs, :edit_response))
          @responded = true
        else
          interaction.send_message(**filter_kwargs(kwargs, :send_message))
        end
      end
    end
    alias reply respond
    alias say respond

    # Acknowledges the interaction without a visible message.
    # @return [nil]
    def defer(ephemeral: config.auto_defer_ephemeral, **kwargs)
      @response_mutex.synchronize do
        return nil if @acknowledged

        interaction.defer(ephemeral: ephemeral, **kwargs)
        @acknowledged = true
        @deferred = true
      end
      nil
    end

    # Edits the original interaction response.
    # @return [Object, nil]
    def edit(content = nil, **kwargs, &)
      kwargs = prepare_response(kwargs, &)
      kwargs[:content] = content unless content.nil?

      @response_mutex.synchronize do
        result = interaction.edit_response(**filter_kwargs(kwargs, :edit_response))
        @acknowledged = true
        @responded = true
        result
      end
    end
    alias edit_response edit

    # Sends a follow-up message.
    # @return [Object]
    def follow_up(content = nil, **kwargs, &)
      kwargs = prepare_response(kwargs, &)
      kwargs[:content] = content unless content.nil?
      interaction.send_message(**filter_kwargs(kwargs, :send_message))
    end

    # Deletes the original interaction response.
    def delete_response
      interaction.delete_response
    end

    # Shows a modal.
    #
    # @param title [String]
    # @param route [Symbol, nil]
    # @param custom_id [String, nil]
    # @param payload [Object, nil] Data embedded or stored in the modal custom ID.
    # @param state [Boolean] Store payload in the state store.
    # @param components [Array, nil]
    # @yieldparam modal [CordKit::ModalBuilder]
    # @return [nil]
    def show_modal(title, route: nil, custom_id: nil, payload: nil, state: false, components: nil, &block)
      custom_id ||= CustomId.build(
        plugin: plugin_name,
        route: route || raise(ArgumentError, "A modal route or custom_id is required."),
        data: payload,
        store: state ? state_store : nil,
        ttl: config.state_ttl
      )

      if block
        modal = CordKit::ModalBuilder.new(plugin: plugin_name, runtime: runtime, &block)
        components ||= modal.to_a
      end

      @response_mutex.synchronize do
        interaction.show_modal(title: title, custom_id: custom_id, components: components || [])
        @acknowledged = true
        @responded = true
      end
      nil
    end
    alias modal show_modal

    # Builds a component view.
    # @yieldparam view [CordKit::View]
    # @return [CordKit::View]
    def view(&)
      CordKit::View.new(plugin: plugin_name, runtime: runtime, &)
    end

    # @return [Boolean]
    def acknowledged?
      @response_mutex.synchronize { @acknowledged }
    end

    # @return [Boolean]
    def deferred?
      @response_mutex.synchronize { @deferred }
    end

    # @return [Boolean]
    def responded?
      @response_mutex.synchronize { @responded }
    end

    # @return [Float] Seconds left in the initial three second response window.
    def remaining_time
      [3.0 - (monotonic_time - @created_at), 0.0].max
    end

    # Raises a friendly user error.
    # @return [void]
    def error!(message, ephemeral: true)
      raise UserError.new(message, ephemeral: ephemeral)
    end

    # Stops processing without an error message.
    # @return [void]
    def halt!
      raise Halt
    end

    protected

    def prepare_response(kwargs, &block)
      view = kwargs.delete(:view)
      raise ArgumentError, "Pass either view: or a block, not both." if view && block

      view = CordKit::View.new(plugin: plugin_name, runtime: runtime, &block) if block

      components = kwargs.delete(:components)
      components = view.to_a if view
      kwargs[:components] = components if components
      kwargs
    end

    def filter_kwargs(kwargs, target)
      kwargs = kwargs.dup
      case target
      when :respond, :send_message
        kwargs.delete(:wait)
      when :edit_response
        kwargs.delete(:ephemeral)
        kwargs.delete(:tts)
        kwargs.delete(:wait)
      end
      kwargs
    end

    def route_custom_id(route)
      CustomId.build(plugin: plugin_name, route: route)
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
