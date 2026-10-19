# frozen_string_literal: true

require "monitor"

module CordKit
  # A per-user, per-guild or global cooldown.
  class Cooldown
    # @return [Float]
    attr_reader :seconds

    # @return [Symbol]
    attr_reader :per

    # @return [String]
    attr_reader :message

    # @param seconds [Numeric]
    # @param per [Symbol] :user, :guild or :global
    # @param message [String, nil]
    def initialize(seconds, per: :user, message: nil)
      unless %i[user guild global].include?(per.to_sym)
        raise ConfigurationError, "Unknown cooldown scope: #{per.inspect}"
      end

      @seconds = seconds.to_f
      raise ConfigurationError, "Cooldown must be greater than zero" unless @seconds.positive?

      @per = per.to_sym
      @message = message
      @buckets = {}
      @monitor = Monitor.new
    end

    # Raises {CooldownError} when the command is cooling down.
    # Marks the command as used when it is not.
    # @param context [CordKit::Context]
    # @param key [String]
    # @return [Float] Remaining seconds before the call.
    def check!(context, key)
      now = monotonic_time
      bucket_key = [key, scope_id(context)]
      @monitor.synchronize do
        reset_at = @buckets[bucket_key]
        if reset_at && reset_at > now
          retry_after = reset_at - now
          raise CooldownError.new(message, retry_after: retry_after)
        end

        @buckets[bucket_key] = now + @seconds
      end
      @seconds
    end

    # @return [Float]
    def remaining(context, key)
      @monitor.synchronize do
        reset_at = @buckets[[key, scope_id(context)]]
        reset_at ? [reset_at - monotonic_time, 0.0].max : 0.0
      end
    end

    # Clears all cooldown buckets.
    def reset!
      @monitor.synchronize { @buckets.clear }
    end

    # Removes expired entries.
    def cleanup!
      now = monotonic_time
      @monitor.synchronize { @buckets.delete_if { |_key, reset_at| reset_at <= now } }
    end

    private

    def scope_id(context)
      case per
      when :user then context.user&.id
      when :guild then context.server&.id || :dm
      when :global then :global
      end
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
