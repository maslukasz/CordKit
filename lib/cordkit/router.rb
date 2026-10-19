# frozen_string_literal: true

module CordKit
  # Routes component interactions to plugin handlers.
  class Router
    # A registered component handler.
    Handler = Struct.new(:plugin, :block, :type, :route, :matcher, keyword_init: true)

    # Select interaction types the router can resolve.
    SELECT_TYPES = %i[string_select user_select role_select mentionable_select channel_select].freeze

    def initialize(runtime)
      @runtime = runtime
      @route_handlers = {}
      @raw_exact_handlers = Hash.new { |hash, key| hash[key] = {} }
      @raw_regex_handlers = Hash.new { |hash, key| hash[key] = [] }
      @autocomplete_handlers = {}
    end

    # @param plugin [CordKit::Plugin]
    # @param definition [CordKit::Plugin::ComponentDefinition]
    # @return [CordKit::Router::Handler]
    def register_component(plugin, definition)
      handler = Handler.new(
        plugin: plugin,
        block: definition.block,
        type: definition.type,
        route: definition.route,
        matcher: definition.matcher
      )

      if definition.route?
        key = [definition.type, plugin.plugin_name, definition.route]
        if @route_handlers.key?(key)
          raise RouteError, "Route #{definition.route.inspect} is already registered for #{plugin.plugin_name.inspect}."
        end

        @route_handlers[key] = handler
      else
        register_raw(definition.type, definition.matcher, handler)
      end

      handler
    end

    # @param plugin [CordKit::Plugin]
    # @param definition [CordKit::Plugin::AutocompleteDefinition]
    # @return [CordKit::Router::Handler]
    def register_autocomplete(plugin, definition)
      key = [
        definition.command_name.to_sym,
        definition.group&.to_sym,
        definition.subcommand&.to_sym,
        definition.option_name.to_sym
      ]
      if @autocomplete_handlers.key?(key)
        raise RouteError, "Autocomplete handler for #{key.inspect} is already registered."
      end

      handler = Handler.new(plugin: plugin, block: definition.block, type: :autocomplete)
      @autocomplete_handlers[key] = handler
    end

    # @param event_type [Symbol]
    # @param custom_id [String]
    # @return [Array(CordKit::Router::Handler, Array, CordKit::CustomId::Parsed), nil]
    def find_component(event_type, custom_id)
      parsed = CustomId.parse(custom_id)

      if parsed
        type_keys(event_type).each do |type|
          handler = @route_handlers[[type, parsed.plugin, parsed.route]]
          return [handler, [], parsed] if handler
        end
      end

      type_keys(event_type).each do |type|
        handler = @raw_exact_handlers[type][custom_id]
        return [handler, [], parsed] if handler

        @raw_regex_handlers[type].each do |matcher, regex_handler|
          match = matcher.match(custom_id)
          return [regex_handler, match.captures, parsed] if match
        end
      end

      nil
    end

    # @param command_name [Symbol, String]
    # @param group [Symbol, String, nil]
    # @param subcommand [Symbol, String, nil]
    # @param option [Symbol, String]
    # @return [CordKit::Router::Handler, nil]
    def find_autocomplete(command_name, group, subcommand, option)
      candidates = [
        [command_name.to_sym, group&.to_sym, subcommand&.to_sym, option.to_sym],
        [command_name.to_sym, nil, nil, option.to_sym]
      ]
      candidates.each do |key|
        handler = @autocomplete_handlers[key]
        return handler if handler
      end
      nil
    end

    # Removes all handlers belonging to a plugin.
    # @param plugin_name [Symbol, String]
    def remove_plugin(plugin_name)
      plugin_name = plugin_name.to_sym
      @route_handlers.delete_if { |(_, name, _route), _handler| name == plugin_name }
      @raw_exact_handlers.each_value do |handlers|
        handlers.delete_if { |_custom_id, handler| handler.plugin.plugin_name == plugin_name }
      end
      @raw_regex_handlers.each_value do |handlers|
        handlers.reject! { |_matcher, handler| handler.plugin.plugin_name == plugin_name }
      end
      @autocomplete_handlers.delete_if { |_key, handler| handler.plugin.plugin_name == plugin_name }
    end

    # @return [Integer]
    def route_count
      @route_handlers.size
    end

    private

    def register_raw(type, matcher, handler)
      case matcher
      when String
        [type, matcher]
        if @raw_exact_handlers[type].key?(matcher)
          raise RouteError, "Custom ID #{matcher.inspect} is already registered."
        end

        @raw_exact_handlers[type][matcher] = handler
      when Regexp
        @raw_regex_handlers[type] << [matcher, handler]
      else
        raise RouteError, "Custom ID matcher must be a String or Regexp."
      end
    end

    def type_keys(event_type)
      keys = [event_type.to_sym]
      keys << :select if SELECT_TYPES.include?(event_type.to_sym)
      keys << :any
      keys.uniq
    end
  end
end
