# frozen_string_literal: true

module CordKit
  # A discordrb bot with an attached CordKit runtime.
  #
  # @example
  #   bot = CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  #     config.guild_ids = [123456789012345678]
  #   end
  #   bot.plugin MyPlugin
  #   bot.run
  class Bot < Discordrb::Bot
    # @return [CordKit::Runtime]
    attr_reader :cordkit

    # @param token [String, nil]
    # @param cordkit [Hash] CordKit configuration options.
    # @param discord_options [Hash] Options forwarded to discordrb.
    # @yieldparam config [CordKit::Configuration]
    def initialize(token: nil, cordkit: {}, **discord_options, &block)
      cordkit_options = extract_cordkit_options(discord_options)
      super(token: token, **discord_options)
      @cordkit = Runtime.new(self, **cordkit.merge(cordkit_options), &block)
    end

    # Registers a plugin class.
    # @return [CordKit::Plugin]
    def plugin(plugin_class)
      @cordkit.register_plugin(plugin_class)
    end
    alias load_plugin plugin

    # @see CordKit::Runtime#unload_plugin
    def unload_plugin(plugin_name)
      @cordkit.unload_plugin(plugin_name)
    end

    # @see CordKit::Runtime#sync_commands!
    def sync_commands!(**options)
      @cordkit.sync_commands!(**options)
    end

    # @see CordKit::Runtime#plugins
    def plugins
      @cordkit.plugins
    end

    # @see CordKit::Runtime#command_registry
    def commands
      @cordkit.command_registry
    end

    private

    def extract_cordkit_options(options)
      keys = Configuration.instance_methods(false).grep(/=$/).map { |method| method.to_s.delete_suffix("=").to_sym }
      keys.each_with_object({}) do |key, result|
        result[key] = options.delete(key) if options.key?(key)
      end
    end
  end
end
