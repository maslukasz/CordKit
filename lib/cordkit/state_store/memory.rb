# frozen_string_literal: true

require "securerandom"
require "time"

module CordKit
  module StateStore
    # Thread-safe in-memory state store. Suitable for a single bot process.
    class Memory
      include StateStore

      # A stored value together with its expiry timestamp.
      Entry = Struct.new(:value, :expires_at)

      # @return [Integer]
      attr_reader :default_ttl

      # @param default_ttl [Integer] Default lifetime in seconds.
      # @param max_entries [Integer] Soft limit protecting against unbounded growth.
      def initialize(default_ttl: 900, max_entries: 10_000)
        @default_ttl = default_ttl
        @max_entries = max_entries
        @data = {}
        @mutex = Mutex.new
      end

      # @return [String]
      def write(value, ttl: nil, key: nil)
        @mutex.synchronize do
          purge_expired!
          key ||= SecureRandom.urlsafe_base64(12)
          @data[key] = Entry.new(value, expires_at(ttl))
          trim!
          key
        end
      end

      # @return [Object, nil]
      def read(key)
        @mutex.synchronize do
          entry = @data[key]
          next nil unless entry

          if expired?(entry)
            @data.delete(key)
            next nil
          end

          entry.value
        end
      end

      # @return [Boolean]
      def delete(key)
        @mutex.synchronize { !@data.delete(key).nil? }
      end

      # @return [Boolean]
      def exist?(key)
        !read(key).nil?
      end

      # Reads a value or stores the block result under +key+.
      # @return [Object]
      def fetch(key, ttl: nil)
        existing = read(key)
        return existing unless existing.nil?

        write(yield, ttl: ttl, key: key)
        read(key)
      end

      # Removes expired entries.
      # @return [Integer] Number of removed entries.
      def cleanup!
        @mutex.synchronize { purge_expired! }
      end

      # @return [Integer]
      def size
        @mutex.synchronize do
          purge_expired!
          @data.size
        end
      end

      alias length size

      private

      def expires_at(ttl)
        ttl = @default_ttl if ttl.nil?
        ttl = ttl.to_f
        return nil if ttl <= 0

        Time.now + ttl
      end

      def expired?(entry)
        entry.expires_at && entry.expires_at <= Time.now
      end

      def purge_expired!
        @data.delete_if { |_key, entry| expired?(entry) }
      end

      def trim!
        return if @data.size <= @max_entries

        @data.delete(@data.keys.first)
        trim! if @data.size > @max_entries
      end
    end
  end
end
