# frozen_string_literal: true

module CordKit
  # Base class for all CordKit errors.
  class Error < StandardError; end

  # Raised when the configuration is invalid or incomplete.
  class ConfigurationError < Error; end

  # Base class for plugin related errors.
  class PluginError < Error; end

  # Raised when a plugin definition is invalid.
  class InvalidPluginError < PluginError; end

  # Base class for command related errors.
  class CommandError < Error; end

  # Raised when a command definition is invalid.
  class InvalidCommandError < CommandError; end

  # Raised when two plugins define the same top level command.
  class DuplicateCommandError < CommandError; end

  # Raised when an option definition is invalid.
  class InvalidOptionError < CommandError; end

  # Base class for custom ID errors.
  class CustomIdError < Error; end

  # Raised when a custom ID cannot be built or parsed.
  class InvalidCustomIdError < CustomIdError; end

  # Raised when a component route is already registered.
  class RouteError < Error; end

  # Raised by a check when the current user may not run a command.
  class CheckFailed < Error
    # @return [String]
    attr_reader :message

    def initialize(message = nil)
      @message = message || "You are not allowed to use this command."
      super(@message)
    end
  end

  # Raised when a command is used during its cooldown.
  class CooldownError < Error
    # @return [Float]
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil)
      @retry_after = retry_after.to_f
      super(message || "This command is on cooldown. Try again in #{@retry_after.ceil} seconds.")
    end
  end

  # Raise this from a command to send a friendly error message.
  class UserError < Error
    # @return [Boolean]
    attr_reader :ephemeral

    def initialize(message, ephemeral: true)
      @ephemeral = ephemeral
      super(message)
    end
  end

  # Raise this from a handler to stop processing without an error message.
  class Halt < StandardError; end
end
