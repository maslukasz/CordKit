# frozen_string_literal: true

module CordKit
  # Runtime configuration for a CordKit bot.
  #
  # @example
  #   bot = CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  #     config.environment = :development
  #     config.guild_ids = [123456789012345678]
  #   end
  class Configuration
    # @return [Symbol] :development or :production
    attr_accessor :environment

    # @return [Symbol] :auto, :guild or :global
    attr_accessor :command_scope

    # @return [Boolean, Symbol] true, false or :on_ready
    attr_accessor :sync

    # @return [Symbol] :replace or :merge
    attr_accessor :sync_mode

    # @return [Array<Integer>, :all, nil] Guild IDs used for guild command sync.
    attr_accessor :guild_ids

    # @return [Float] Seconds after which a slow command is deferred.
    attr_accessor :auto_defer_after

    # @return [Boolean] Whether automatic defers should be ephemeral.
    attr_accessor :auto_defer_ephemeral

    # @return [String] Message sent for unexpected errors.
    attr_accessor :default_error_message

    # @return [String, nil] Message sent for an unhandled component interaction.
    attr_accessor :unknown_interaction_message

    # @return [CordKit::StateStore, nil]
    attr_accessor :state_store

    # @return [Integer] Default state lifetime in seconds.
    attr_accessor :state_ttl

    # @return [Logger, Discordrb::Logger] Logger used by CordKit.
    attr_accessor :logger

    # @return [Array<Integer>] Discord user IDs treated as bot owners.
    attr_accessor :owner_ids

    # @return [Boolean] Whether command definitions are validated while loading.
    attr_accessor :validate_on_load

    # @return [Proc, nil] Optional global error hook.
    attr_accessor :on_error

    def initialize
      @environment = ENV.fetch("CORDKIT_ENV", "development").to_sym
      @command_scope = :auto
      @sync = :on_ready
      @sync_mode = :replace
      @guild_ids = nil
      @auto_defer_after = 1.5
      @auto_defer_ephemeral = false
      @default_error_message = "Something went wrong while handling this interaction."
      @unknown_interaction_message = "This interaction is no longer available."
      @state_store = nil
      @state_ttl = 900
      @logger = nil
      @owner_ids = []
      @validate_on_load = true
      @on_error = nil
    end

    # @return [Boolean]
    def production?
      environment.to_sym == :production
    end

    # @return [Boolean]
    def development?
      !production?
    end

    # Resolves :auto to :guild in development and :global in production.
    # @return [Symbol]
    def effective_command_scope
      return command_scope.to_sym unless command_scope.to_sym == :auto

      production? ? :global : :guild
    end

    # @return [Array<Integer>, :all]
    def effective_guild_ids
      return guild_ids if guild_ids == :all

      Array(guild_ids).compact.map(&:to_i)
    end

    # @return [Boolean]
    def sync?
      sync != false && !sync.nil?
    end

    # @return [Boolean]
    def merge_commands?
      sync_mode.to_sym == :merge
    end
  end
end
