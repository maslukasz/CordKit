# frozen_string_literal: true

require "json"

module CordKit
  # Synchronizes command definitions with Discord using discordrb's API module.
  class Synchronizer
    # Fields Discord accepts when re-sending an existing command during a merge sync.
    PRESERVED_FIELDS = %w[
      name description options type default_member_permissions contexts integration_types nsfw name_localizations
      description_localizations
    ].freeze

    # @param runtime [CordKit::Runtime]
    def initialize(runtime)
      @runtime = runtime
    end

    # @param scope [Symbol, nil] :global, :guild or :auto
    # @param mode [Symbol, nil] :replace or :merge
    # @param guild_ids [Array<Integer>, :all, nil]
    def sync!(scope: nil, mode: nil, guild_ids: nil)
      scope = (scope || @runtime.config.effective_command_scope).to_sym
      mode = (mode || @runtime.config.sync_mode).to_sym

      case scope
      when :global
        sync_global!(mode)
      when :guild
        sync_guilds!(mode, guild_ids)
      else
        raise ConfigurationError, "Unknown command scope: #{scope.inspect}"
      end
    end

    # @return [String] Raw Discord API response.
    def sync_global!(mode = @runtime.config.sync_mode)
      payloads = @runtime.command_registry.payloads
      payloads = merge_global(payloads) if mode.to_sym == :merge
      Discordrb::API::Application.bulk_overwrite_global_commands(
        @runtime.bot.token,
        application_id,
        payloads
      )
    end

    # @return [Hash{Integer => String}]
    def sync_guilds!(mode = @runtime.config.sync_mode, guild_ids = nil)
      ids = normalize_guild_ids(guild_ids)
      raise ConfigurationError, "No guild IDs configured for guild command sync." if ids.empty?

      payloads = @runtime.command_registry.payloads
      ids.to_h do |guild_id|
        guild_payloads = mode.to_sym == :merge ? merge_guild(payloads, guild_id) : payloads
        response = Discordrb::API::Application.bulk_overwrite_guild_commands(
          @runtime.bot.token,
          application_id,
          guild_id,
          guild_payloads
        )
        [guild_id, response]
      end
    end

    private

    def application_id
      @runtime.bot.profile.id
    rescue StandardError
      @runtime.bot.bot_application&.id || raise(ConfigurationError, "Could not determine the application ID.")
    end

    def normalize_guild_ids(guild_ids)
      configured = guild_ids || @runtime.config.guild_ids
      return @runtime.bot.servers.keys if configured == :all

      Array(configured).compact.map(&:to_i)
    end

    def merge_global(payloads)
      existing = JSON.parse(
        Discordrb::API::Application.get_global_commands(@runtime.bot.token, application_id)
      )
      merge_payloads(existing, payloads)
    end

    def merge_guild(payloads, guild_id)
      existing = JSON.parse(
        Discordrb::API::Application.get_guild_commands(@runtime.bot.token, application_id, guild_id)
      )
      merge_payloads(existing, payloads)
    end

    def merge_payloads(existing, payloads)
      managed = payloads.map { |payload| (payload[:name] || payload["name"]).to_s }
      kept = existing.reject { |command| managed.include?(command["name"].to_s) }
      kept.map { |command| command.slice(*PRESERVED_FIELDS) } + payloads
    end
  end
end
