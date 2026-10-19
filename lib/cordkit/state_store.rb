# frozen_string_literal: true

module CordKit
  # Interface used by CordKit to store state referenced from custom IDs.
  #
  # Implement this interface to use Redis or another shared store.
  module StateStore
    # @param value [Object] Any JSON serializable value.
    # @param ttl [Integer, nil] Lifetime in seconds.
    # @param key [String, nil] Optional explicit key.
    # @return [String] The key under which the value was stored.
    def write(value, ttl: nil, key: nil)
      raise NotImplementedError
    end

    # @param key [String]
    # @return [Object, nil]
    def read(key)
      raise NotImplementedError
    end

    # @param key [String]
    # @return [Boolean]
    def delete(key)
      raise NotImplementedError
    end

    # @param key [String]
    # @return [Boolean]
    def exist?(key)
      !read(key).nil?
    end
  end
end
