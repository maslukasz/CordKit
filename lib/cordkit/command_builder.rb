# frozen_string_literal: true

module CordKit
  # Fluent builder used by the plugin DSL.
  class CommandBuilder
    # @return [String]
    attr_reader :name

    # @return [Symbol]
    attr_reader :type

    # @return [Array<CordKit::OptionDefinition>]
    attr_reader :options

    # @return [Hash<Symbol, CordKit::Command>]
    attr_reader :subcommands

    # @return [Hash<Symbol, CordKit::Command>]
    attr_reader :subcommand_groups

    # @return [CordKit::Command, nil]
    attr_reader :parent

    def initialize(name, plugin_class:, description: nil, type: :chat_input, parent: nil)
      @name = name.to_s
      @description = description.to_s
      @description = default_description(@name) if @description.empty?
      @type = type.to_sym
      @plugin_class = plugin_class
      @parent = parent
      @options = []
      @subcommands = {}
      @subcommand_groups = {}
      @handler = nil
      @autocomplete_handlers = {}
      @checks = []
      @cooldown = nil
      @defer = nil
      @default_member_permissions = nil
      @contexts = nil
      @integration_types = nil
      @nsfw = false
      @name_localizations = nil
      @description_localizations = nil
    end

    # Sets or returns the description.
    # @param value [String, nil]
    # @return [String, self]
    def description(value = nil)
      return @description if value.nil?

      @description = value.to_s
      self
    end

    # Sets the command handler.
    # @yieldparam context [CordKit::Context]
    # @return [self]
    def run(&block)
      raise ArgumentError, "A command handler block is required" unless block

      @handler = block
      self
    end
    alias handle run
    alias execute run

    # Adds an option.
    # @return [self]
    def option(name, type, description, **options)
      @options << OptionDefinition.new(name, type, description, **options)
      self
    end

    # Adds a string option.
    # @return [self]
    def string(name, description, **options) = option(name, :string, description, **options)

    # Adds an integer option.
    # @return [self]
    def integer(name, description, **options) = option(name, :integer, description, **options)

    # Adds a floating point option.
    # @return [self]
    def number(name, description, **options) = option(name, :number, description, **options)

    # Adds a boolean option.
    # @return [self]
    def boolean(name, description, **options) = option(name, :boolean, description, **options)

    # Adds a user option.
    # @return [self]
    def user(name, description, **options) = option(name, :user, description, **options)

    # Adds a channel option.
    # @return [self]
    def channel(name, description, **options) = option(name, :channel, description, **options)

    # Adds a role option.
    # @return [self]
    def role(name, description, **options) = option(name, :role, description, **options)

    # Adds a user-or-role option.
    # @return [self]
    def mentionable(name, description, **options) = option(name, :mentionable, description, **options)

    # Adds a file attachment option.
    # @return [self]
    def attachment(name, description, **options) = option(name, :attachment, description, **options)

    # Registers an autocomplete handler for an option.
    # @return [self]
    def autocomplete(name, &block)
      raise ArgumentError, "An autocomplete block is required" unless block

      @autocomplete_handlers[name.to_sym] = block
      self
    end

    # Adds a subcommand.
    # @return [self]
    def subcommand(name, description = nil, &block)
      builder = CommandBuilder.new(name, description: description, type: :subcommand, plugin_class: @plugin_class,
                                         parent: nil)
      apply_block(builder, block)
      @subcommands[name.to_sym] = builder
      self
    end

    # Adds a subcommand group.
    # @return [self]
    def subcommand_group(name, description = nil, &block)
      builder = CommandBuilder.new(name, description: description, type: :subcommand_group,
                                         plugin_class: @plugin_class, parent: nil)
      if block
        raise ArgumentError, "A subcommand group block must not accept arguments" unless block.arity.zero?

        builder.instance_eval(&block)
      end
      @subcommand_groups[name.to_sym] = builder
      self
    end
    alias group subcommand_group

    # Adds a custom check.
    # @return [self]
    def check(name = nil, message: nil, &block)
      @checks << Checks.custom(name: name, message: message, &block)
      self
    end

    # @return [self]
    def guild_only(message: "This command can only be used in a server.")
      @checks << Checks.guild_only(message: message)
      self
    end

    # @return [self]
    def dm_only(message: "This command can only be used in DMs.")
      @checks << Checks.dm_only(message: message)
      self
    end

    # @return [self]
    def require_permissions(*permissions, any: false, message: nil)
      @checks << Checks.user_permissions(*permissions, any: any, message: message)
      self
    end
    alias user_permissions require_permissions

    # @return [self]
    def require_bot_permissions(*permissions, any: false, message: nil)
      @checks << Checks.bot_permissions(*permissions, any: any, message: message)
      self
    end
    alias bot_permissions require_bot_permissions

    # @return [self]
    def require_roles(*roles, any: false, message: nil)
      @checks << Checks.roles(*roles, any: any, message: message)
      self
    end
    alias roles require_roles

    # @return [self]
    def require_users(*user_ids, message: nil)
      @checks << Checks.users(*user_ids, **check_message(message))
      self
    end

    # @return [self]
    def require_servers(*server_ids, message: nil)
      @checks << Checks.servers(*server_ids, **check_message(message))
      self
    end

    # @return [self]
    def allow_channels(*channel_ids, message: nil)
      @checks << Checks.channels(*channel_ids, **check_message(message))
      self
    end

    # @return [self]
    def owner_only(ids = nil, message: nil)
      @checks << Checks.owner_only(ids, message: message)
      self
    end

    # @return [self]
    def nsfw(value: true)
      @nsfw = value
      self
    end

    # Configures a cooldown.
    # @return [self]
    def cooldown(seconds = nil, per: :user, message: nil)
      return @cooldown if seconds.nil?

      @cooldown = Cooldown.new(seconds, per: per, message: message)
      self
    end

    # Defers the interaction automatically before running the handler.
    # @return [self]
    def defer(value: true)
      @defer = value
      self
    end

    # @return [self]
    def default_member_permissions(*permissions)
      @default_member_permissions = permissions.flatten
      self
    end

    # @return [self]
    def contexts(*values)
      @contexts = values.flatten
      self
    end

    # @return [self]
    def integration_types(*values)
      @integration_types = values.flatten
      self
    end

    # @return [self]
    def name_localizations(value)
      @name_localizations = value
      self
    end

    # @return [self]
    def description_localizations(value)
      @description_localizations = value
      self
    end

    # @param parent [CordKit::Command, nil]
    # @return [CordKit::Command]
    def to_command(parent: nil)
      command = Command.new(
        plugin_class: @plugin_class,
        name: @name,
        type: @type,
        description: @description,
        options: @options,
        subcommands: {},
        subcommand_groups: {},
        handler: @handler,
        autocomplete_handlers: @autocomplete_handlers,
        checks: @checks,
        cooldown: @cooldown,
        defer: @defer,
        parent: parent,
        default_member_permissions: @default_member_permissions,
        contexts: @contexts,
        integration_types: @integration_types,
        nsfw: @nsfw,
        name_localizations: @name_localizations,
        description_localizations: @description_localizations
      )

      @subcommands.each do |name, builder|
        command.subcommands[name] = builder.to_command(parent: command)
      end
      @subcommand_groups.each do |name, builder|
        command.subcommand_groups[name] = builder.to_command(parent: command)
      end

      command
    end
    alias build to_command

    private

    # Builds a readable description when the author does not provide one, so
    # `command :ping do ... end` is valid for beginners.
    # @param name [String]
    # @return [String]
    def default_description(name)
      words = name.to_s.tr("_-", " ").strip
      return "Command" if words.empty?

      "#{words[0].upcase}#{words[1..]} command"
    end

    def check_message(message)
      message ? { message: message } : {}
    end

    def apply_block(builder, block)
      return unless block

      if block.arity.zero?
        builder.instance_eval(&block)
      else
        builder.run(&block)
      end
    end
  end
end
