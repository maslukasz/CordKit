# frozen_string_literal: true

module CordKit
  # A command definition. Commands may be top level, subcommands or subcommand groups.
  class Command
    # Pattern Discord accepts for slash command names.
    SLASH_NAME_PATTERN = /\A[a-z0-9_-]{1,32}\z/

    # Command types that can be registered at the top level.
    TOP_LEVEL_TYPES = %i[chat_input user message].freeze

    # Every command type CordKit understands.
    ALL_TYPES = %i[chat_input user message subcommand subcommand_group].freeze

    # @return [Class] The plugin class that owns this command.
    attr_reader :plugin_class

    # @return [String]
    attr_reader :name

    # @return [Symbol]
    attr_reader :type

    # @return [String]
    attr_reader :description

    # @return [Array<CordKit::OptionDefinition>]
    attr_reader :options

    # @return [Hash<Symbol, CordKit::Command>]
    attr_reader :subcommands

    # @return [Hash<Symbol, CordKit::Command>]
    attr_reader :subcommand_groups

    # @return [Proc, nil]
    attr_reader :handler

    # @return [Hash<Symbol, Proc>]
    attr_reader :autocomplete_handlers

    # @return [Array<CordKit::Check>]
    attr_reader :checks

    # @return [CordKit::Cooldown, nil]
    attr_reader :cooldown

    # @return [Boolean, nil]
    attr_reader :defer

    # @return [CordKit::Command, nil]
    attr_reader :parent

    # @return [Array<Symbol>, nil]
    attr_reader :default_member_permissions

    # @return [Array<Symbol, Integer>, nil]
    attr_reader :contexts

    # @return [Array<Symbol, Integer>, nil]
    attr_reader :integration_types

    # @return [Boolean]
    attr_reader :nsfw

    # @return [Hash, nil]
    attr_reader :name_localizations

    # @return [Hash, nil]
    attr_reader :description_localizations

    def initialize(plugin_class:, name:, type: :chat_input, description: nil, options: [], subcommands: {},
                   subcommand_groups: {}, handler: nil, autocomplete_handlers: {}, checks: [], cooldown: nil,
                   defer: nil, parent: nil, default_member_permissions: nil, contexts: nil, integration_types: nil,
                   nsfw: false, name_localizations: nil, description_localizations: nil)
      @plugin_class = plugin_class
      @name = name.to_s
      @type = type.to_sym
      @description = description.to_s
      @options = options
      @subcommands = subcommands
      @subcommand_groups = subcommand_groups
      @handler = handler
      @autocomplete_handlers = autocomplete_handlers
      @checks = checks
      @cooldown = cooldown
      @defer = defer
      @parent = parent
      @default_member_permissions = default_member_permissions
      @contexts = contexts
      @integration_types = integration_types
      @nsfw = nsfw ? true : false
      @name_localizations = name_localizations
      @description_localizations = description_localizations
    end

    # @return [Boolean]
    def top_level?
      parent.nil?
    end

    # @return [Boolean]
    def leaf?
      subcommands.empty? && subcommand_groups.empty?
    end

    # @return [String] Space separated command path, e.g. "config set".
    def full_name
      return name unless parent

      "#{parent.full_name} #{name}"
    end

    # @return [Array<CordKit::Check>]
    def effective_checks
      inherited = parent ? parent.effective_checks : []
      inherited + checks
    end

    # @return [CordKit::Cooldown, nil]
    def effective_cooldown
      cooldown || parent&.effective_cooldown
    end

    # @return [Boolean, nil]
    def effective_defer
      defer.nil? ? parent&.effective_defer : defer
    end

    # @return [Hash]
    def to_h
      payload = {
        name: name,
        description: (description unless context_menu?),
        type: top_level_type_value,
        options: options_payload,
        default_member_permissions: default_member_permissions_value,
        contexts: contexts_value,
        integration_types: integration_types_value,
        nsfw: (true if nsfw),
        name_localizations: stringify_keys(name_localizations),
        description_localizations: stringify_keys(description_localizations)
      }
      payload.compact
    end

    # @return [Hash]
    def subcommand_payload
      {
        type: 1,
        name: name,
        description: description,
        options: options.map(&:to_h),
        name_localizations: stringify_keys(name_localizations),
        description_localizations: stringify_keys(description_localizations)
      }.compact
    end

    # @return [Hash]
    def group_payload
      {
        type: 2,
        name: name,
        description: description,
        options: subcommands.values.map(&:subcommand_payload),
        name_localizations: stringify_keys(name_localizations),
        description_localizations: stringify_keys(description_localizations)
      }.compact
    end

    # @return [Array<Hash>]
    def options_payload
      return options.map(&:to_h) if leaf?

      subcommands.values.map(&:subcommand_payload) + subcommand_groups.values.map(&:group_payload)
    end

    # @return [Boolean]
    def context_menu?
      %i[user message].include?(type)
    end

    # @return [Boolean]
    def chat_input?
      type == :chat_input
    end

    # @return [Symbol, nil]
    def leaf_type
      type
    end

    # Validates the command and all children.
    # @raise [CordKit::InvalidCommandError]
    def validate!
      validate_name!
      validate_type!
      validate_description!
      validate_structure!
      validate_autocomplete_handlers!
      validate_options!
      validate_attributes!
      subcommands.each_value(&:validate!)
      subcommand_groups.each_value(&:validate!)
      self
    end

    # Normalizes values received from Discord using resolved data.
    # @param event [Discordrb::Events::ApplicationCommandEvent]
    # @return [Hash<Symbol, Object>]
    def normalize_options(event)
      raw = event.respond_to?(:options) ? event.options : {}
      resolved = event.respond_to?(:resolved) ? event.resolved : nil
      options.each_with_object({}) do |option, result|
        key = if raw.key?(option.name)
                option.name
              elsif raw.key?(option.name.to_sym)
                option.name.to_sym
              else
                next
              end
        result[option.name.to_sym] = option.normalize(raw[key], resolved, event.bot)
      end
    end

    private

    def validate_name!
      return if context_menu?

      return if name.match?(SLASH_NAME_PATTERN)

      raise InvalidCommandError,
            "Invalid command name #{name.inspect}. Use 1-32 lowercase letters, digits, '-' or '_'."
    end

    def validate_type!
      raise InvalidCommandError, "Unknown command type: #{type.inspect}" unless ALL_TYPES.include?(type)
      return if top_level? || %i[subcommand subcommand_group].include?(type)

      raise InvalidCommandError, "Subcommands must use :subcommand or :subcommand_group types."
    end

    def validate_description!
      return if context_menu?

      return unless description.empty? || description.length > 100

      raise InvalidCommandError, "Command #{full_name.inspect} description must be 1-100 characters long."
    end

    def validate_structure!
      if type == :subcommand_group
        if subcommands.empty?
          raise InvalidCommandError,
                "Subcommand group #{name.inspect} must contain at least one subcommand."
        end
        if subcommand_groups.any?
          raise InvalidCommandError,
                "Subcommand group #{name.inspect} cannot contain nested groups."
        end
        raise InvalidCommandError, "Subcommand group #{name.inspect} cannot have a handler." if handler

        return
      end

      if type == :subcommand
        if subcommands.any? || subcommand_groups.any?
          raise InvalidCommandError,
                "Subcommand #{full_name.inspect} cannot contain subcommands."
        end
        raise InvalidCommandError, "Subcommand #{full_name.inspect} needs a handler." unless handler

        return
      end

      if context_menu?
        raise InvalidCommandError, "Context menu #{name.inspect} needs a handler." if handler.nil?
        if subcommands.any? || subcommand_groups.any? || options.any?
          raise InvalidCommandError, "Context menu #{name.inspect} cannot have options or subcommands."
        end

        return
      end

      # Chat input command.
      if leaf?
        raise InvalidCommandError, "Command #{name.inspect} needs a handler." unless handler
      else
        if options.any?
          raise InvalidCommandError,
                "Command #{name.inspect} cannot mix subcommands and option definitions."
        end
        if subcommands.any? && subcommand_groups.any?
          raise InvalidCommandError,
                "Command #{name.inspect} cannot mix subcommands and subcommand groups."
        end
        raise InvalidCommandError, "Command #{name.inspect} cannot have a handler when it has subcommands." if handler
      end
    end

    def validate_options!
      return if options.empty?

      raise InvalidCommandError, "Command #{full_name.inspect} can have at most 25 options." if options.size > 25

      names = options.map(&:name)
      duplicate = names.detect { |option_name| names.count(option_name) > 1 }
      raise InvalidCommandError, "Duplicate option name #{duplicate.inspect} in #{full_name.inspect}." if duplicate

      optional_seen = false
      options.each do |option|
        option.validate!
        optional_seen = true unless option.required
        if option.required && optional_seen
          raise InvalidCommandError, "Required option #{option.name.inspect} cannot follow an optional option."
        end
      end
    end

    def validate_autocomplete_handlers!
      autocomplete_handlers.each_key do |option_name|
        option = options.find { |candidate| candidate.name == option_name.to_s }
        unless option
          raise InvalidCommandError,
                "Autocomplete handler for unknown option #{option_name.inspect} in #{full_name.inspect}."
        end

        option.autocomplete = true
      end
    end

    def validate_attributes!
      if default_member_permissions
        context_name = default_member_permissions.is_a?(Array) ? "permissions" : "value"
        unless default_member_permissions.is_a?(Array) ||
               default_member_permissions.is_a?(String) ||
               default_member_permissions.is_a?(Integer)
          raise InvalidCommandError,
                "Invalid default_member_permissions #{context_name}."
        end
      end

      %i[contexts integration_types].each do |attribute|
        value = public_send(attribute)
        next if value.nil?
        raise InvalidCommandError, "#{attribute} must be an array." unless value.is_a?(Array)

        value.each do |entry|
          next if entry.is_a?(Integer)
          next if entry.is_a?(Symbol)

          raise InvalidCommandError, "#{attribute} entries must be symbols or integers."
        end
      end
    end

    def top_level_type_value
      Discordrb::ApplicationCommand::TYPES.fetch(type)
    end

    def default_member_permissions_value
      value = default_member_permissions
      return nil if value.nil?

      case value
      when Array
        Discordrb::Permissions.bits(value.map(&:to_sym)).to_s
      else
        value.to_s
      end
    end

    def contexts_value
      map_values(contexts, { guild: 0, bot_dm: 1, private_channel: 2, dm: 1 })
    end

    def integration_types_value
      map_values(integration_types, { guild_install: 0, user_install: 1 })
    end

    def map_values(values, mapping)
      return nil if values.nil?

      values.map { |value| value.is_a?(Integer) ? value : mapping.fetch(value.to_sym) }
    end

    def stringify_keys(hash)
      hash&.to_h { |key, value| [key.to_s, value] }
    end
  end
end
