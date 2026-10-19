# frozen_string_literal: true

require "base64"
require "json"

module CordKit
  # Builds and parses CordKit component custom IDs.
  #
  # Format:
  #   dk1:<plugin>:<route>:d.<base64url-json>
  #   dk1:<plugin>:<route>:s.<state-token>
  #   dk1:<plugin>:<route>
  module CustomId
    # Version marker that prefixes every CordKit custom ID.
    PREFIX = "dk1"

    # Discord's hard limit for a custom ID.
    MAX_LENGTH = 100

    # Pattern accepted for plugin names and route names.
    NAME_PATTERN = /\A[a-z0-9_-]{1,32}\z/

    # A parsed custom ID.
    #
    # @!attribute [r] plugin
    #   @return [Symbol, nil]
    # @!attribute [r] route
    #   @return [Symbol, nil]
    # @!attribute [r] data
    #   @return [Hash, nil] Inline payload decoded from the custom ID.
    # @!attribute [r] token
    #   @return [String, nil] State store token when the payload did not fit inline.
    Parsed = Struct.new(:plugin, :route, :data, :token, keyword_init: true) do
      def inline?
        !token
      end

      def state?
        !token.nil?
      end
    end

    module_function

    # @param plugin [Symbol, String]
    # @param route [Symbol, String]
    # @param data [Object, nil]
    # @param store [CordKit::StateStore, nil]
    # @param ttl [Integer, nil]
    # @return [String]
    def build(plugin:, route:, data: nil, store: nil, ttl: nil)
      plugin = normalize_name(plugin, "plugin")
      route = normalize_name(route, "route")
      base = "#{PREFIX}:#{plugin}:#{route}"
      return base if data.nil?

      encoded = Base64.urlsafe_encode64(JSON.generate(data), padding: false)
      candidate = "#{base}:d.#{encoded}"
      return candidate if candidate.bytesize <= MAX_LENGTH

      unless store
        raise InvalidCustomIdError,
              "Custom ID is too long (#{candidate.bytesize}/#{MAX_LENGTH}): #{candidate}"
      end

      token = store.write(data, ttl: ttl)
      candidate = "#{base}:s.#{token}"
      return candidate if candidate.bytesize <= MAX_LENGTH

      raise InvalidCustomIdError, "Custom ID is still too long (#{candidate.bytesize}/#{MAX_LENGTH}): #{candidate}"
    end

    # @param custom_id [String]
    # @return [Parsed, nil]
    def parse(custom_id)
      return nil unless custom_id.is_a?(String)

      parts = custom_id.split(":", 4)
      return nil unless parts.length >= 3 && parts[0] == PREFIX

      plugin = parts[1]
      route = parts[2]
      suffix = parts[3]
      return nil unless valid_name?(plugin) && valid_name?(route)

      return Parsed.new(plugin: plugin.to_sym, route: route, data: nil, token: nil) if suffix.nil?

      kind, payload = suffix.split(".", 2)
      case kind
      when "d"
        Parsed.new(plugin: plugin.to_sym, route: route, data: decode(payload), token: nil)
      when "s"
        Parsed.new(plugin: plugin.to_sym, route: route, data: nil, token: payload)
      end
    rescue JSON::ParserError, ArgumentError
      nil
    end

    # @param value [Object]
    # @return [String]
    def encode(value)
      Base64.urlsafe_encode64(JSON.generate(value), padding: false)
    end

    # @param value [String]
    # @return [Object]
    def decode(value)
      return nil if value.nil?

      padding = "=" * ((4 - (value.length % 4)) % 4)
      JSON.parse(Base64.urlsafe_decode64(value + padding))
    end

    def normalize_name(value, label)
      name = value.to_s
      raise InvalidCustomIdError, "Invalid #{label} name: #{name.inspect}" unless valid_name?(name)

      name
    end

    def valid_name?(value)
      value.is_a?(String) && value.match?(NAME_PATTERN)
    end
  end
end
