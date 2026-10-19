# frozen_string_literal: true

module CordKit
  # A discordrb component view with route-aware custom IDs.
  #
  # @example
  #   view = CordKit::View.new(plugin: :tickets, runtime: runtime) do |v|
  #     v.row do
  #       button :open, style: :primary, label: "Open ticket"
  #     end
  #   end
  class View < Discordrb::Webhooks::View
    # @return [Symbol]
    attr_reader :plugin_name

    # @return [CordKit::Runtime]
    attr_reader :runtime

    # @return [Object, nil]
    attr_reader :payload

    # @return [CordKit::StateStore, nil]
    attr_reader :state_store

    # @return [Boolean]
    attr_reader :state

    # @param plugin [Symbol, String]
    # @param runtime [CordKit::Runtime]
    # @param payload [Object, nil] Inline data embedded in generated custom IDs.
    # @param state [Boolean] Store payload in the state store instead of inlining it.
    # @param store [CordKit::StateStore, nil]
    def initialize(plugin:, runtime:, payload: nil, state: false, store: nil, &block)
      @plugin_name = plugin.to_sym
      @runtime = runtime
      @payload = payload
      @state = state
      @state_store = store || runtime.state_store
      super(&nil)
      yield self if block
    end

    # Returns a route-aware custom ID.
    # @param route [Symbol, String]
    # @param data [Object, nil]
    # @return [String]
    def custom_id(route, data: payload)
      CustomId.build(
        plugin: plugin_name,
        route: route,
        data: data,
        store: state ? state_store : nil,
        ttl: runtime.config.state_ttl
      )
    end

    # Adds an action row.
    # @return [CordKit::View::RowBuilder]
    def row(&block)
      builder = RowBuilder.new(self)
      if block
        block.arity.zero? ? builder.instance_eval(&block) : yield(builder)
      end
      @components << builder.to_h
      builder
    end

    # A row builder that accepts a route as the first positional argument.
    class RowBuilder < Discordrb::Webhooks::View::RowBuilder
      def initialize(view)
        @view = view
        super()
      end

      # Adds a button. Pass a route (Symbol or String) or an explicit custom_id.
      # @return [Hash]
      def button(route = nil, style: :primary, custom_id: nil, **options)
        super(style: style, custom_id: resolve(route, custom_id), **options)
      end

      # Adds a string select menu.
      # @return [Hash]
      def string_select(route = nil, custom_id: nil, **options, &block)
        super(custom_id: resolve(route, custom_id), **options, &block)
      end
      alias select_menu string_select
      alias select string_select

      # Adds a user select menu.
      # @return [Hash]
      def user_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a role select menu.
      # @return [Hash]
      def role_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a mentionable select menu.
      # @return [Hash]
      def mentionable_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a channel select menu.
      # @return [Hash]
      def channel_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      private

      def resolve(route, custom_id)
        return custom_id if custom_id

        case route
        when Symbol
          @view.custom_id(route)
        when String
          route
        when nil
          raise ArgumentError, "A route or custom_id is required for this component."
        else
          raise ArgumentError, "Component route must be a Symbol, String or custom_id."
        end
      end
    end
  end
end
