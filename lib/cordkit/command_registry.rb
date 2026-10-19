# frozen_string_literal: true

module CordKit
  # Registry of top level commands.
  class CommandRegistry
    include Enumerable

    def initialize
      @commands = {}
    end

    # @param command [CordKit::Command]
    # @return [CordKit::Command]
    def add(command)
      raise InvalidCommandError, "Only top level commands can be registered." unless command.top_level?

      key = command.name.to_sym
      if @commands.key?(key)
        existing = @commands[key].plugin_class.plugin_name.inspect
        raise DuplicateCommandError, "Command #{command.name.inspect} is already defined by #{existing}."
      end

      @commands[key] = command
    end

    # Checks for conflicts without registering.
    # @param command [CordKit::Command]
    def validate!(command)
      key = command.name.to_sym
      return unless @commands.key?(key)

      raise DuplicateCommandError,
            "Command #{command.name.inspect} is already defined by #{@commands[key].plugin_class.plugin_name.inspect}."
    end

    # @param name [Symbol, String]
    # @return [CordKit::Command, nil]
    def [](name)
      @commands[name.to_sym]
    end

    # @return [Array<CordKit::Command>]
    def all
      @commands.values
    end

    # @return [Array<Hash>]
    def payloads
      @commands.values.map(&:to_h)
    end

    # @param plugin_name [Symbol, String]
    def remove_plugin(plugin_name)
      @commands.delete_if { |_name, command| command.plugin_class.plugin_name == plugin_name.to_sym }
    end

    # Iterates over registered commands.
    # @yieldparam command [CordKit::Command]
    # @return [Enumerator, void]
    def each(&)
      @commands.each_value(&)
    end

    # Removes every registered command.
    # @return [Hash]
    def clear
      @commands.clear
    end

    # @return [Integer] Number of registered commands.
    def size
      @commands.size
    end
  end
end
