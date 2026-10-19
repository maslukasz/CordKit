# frozen_string_literal: true

module CordKit
  # A single slash command option.
  class OptionDefinition
    # Discord option type codes keyed by CordKit's short names.
    TYPES = {
      string: 3,
      integer: 4,
      boolean: 5,
      user: 6,
      channel: 7,
      role: 8,
      mentionable: 9,
      number: 10,
      attachment: 11
    }.freeze

    # Types that may declare `autocomplete: true`.
    AUTOCOMPLETE_TYPES = %i[string integer number].freeze

    # Types that may declare a static `choices` list.
    CHOICE_TYPES = AUTOCOMPLETE_TYPES

    # Pattern Discord accepts for option names.
    NAME_PATTERN = /\A[a-z0-9_-]{1,32}\z/

    # @return [String]
    attr_reader :name

    # @return [Symbol]
    attr_reader :type

    # @return [String]
    attr_reader :description

    # @return [Boolean]
    attr_accessor :required

    # @return [Boolean]
    attr_accessor :autocomplete

    # @return [Array<Hash>, Hash, nil]
    attr_accessor :choices

    # @return [Array<Symbol, Integer>, nil]
    attr_accessor :channel_types

    # @return [Hash, nil]
    attr_accessor :name_localizations

    # @return [Hash, nil]
    attr_accessor :description_localizations

    def initialize(name, type, description, required: false, choices: nil, autocomplete: false, channel_types: nil,
                   min_length: nil, max_length: nil, min_value: nil, max_value: nil, name_localizations: nil,
                   description_localizations: nil)
      @name = name.to_s
      @type = normalize_type(type)
      @description = description.to_s
      @required = required ? true : false
      @choices = choices
      @autocomplete = autocomplete ? true : false
      @channel_types = channel_types
      @min_length = min_length
      @max_length = max_length
      @min_value = min_value
      @max_value = max_value
      @name_localizations = name_localizations
      @description_localizations = description_localizations
    end

    # @return [Integer, nil]
    attr_reader :min_length, :max_length, :min_value, :max_value

    # @return [Boolean]
    def autocomplete?
      autocomplete
    end

    # @return [Boolean]
    def supports_autocomplete?
      AUTOCOMPLETE_TYPES.include?(type)
    end

    # @return [Boolean]
    def supports_choices?
      CHOICE_TYPES.include?(type)
    end

    # @return [Hash]
    def to_h
      payload = {
        type: TYPES.fetch(type),
        name: name,
        description: description,
        required: (required ? true : nil),
        choices: choices_payload,
        autocomplete: (autocomplete ? true : nil),
        channel_types: channel_types_payload,
        min_length: min_length,
        max_length: max_length,
        min_value: min_value,
        max_value: max_value,
        name_localizations: stringify_keys(name_localizations),
        description_localizations: stringify_keys(description_localizations)
      }
      payload.compact
    end

    # Validates this option definition.
    # @raise [CordKit::InvalidOptionError]
    def validate!
      unless name.match?(NAME_PATTERN)
        raise InvalidOptionError, "Invalid option name #{name.inspect}. Use 1-32 lowercase letters, digits, '-' or '_'."
      end

      if description.empty? || description.length > 100
        raise InvalidOptionError, "Option #{name.inspect} description must be 1-100 characters long."
      end

      validate_choices!
      validate_autocomplete!
      validate_lengths!
      validate_values!
      validate_channel_types!
      self
    end

    # Converts a raw Discord option value into a rich discordrb object when possible.
    # @param value [Object]
    # @param resolved [Discordrb::Events::InteractionCreateEvent::Resolved, nil]
    # @param bot [Discordrb::Bot]
    # @return [Object]
    def normalize(value, resolved, bot)
      return nil if value.nil?

      case type
      when :user
        resolved_lookup(resolved, :members, value) ||
          resolved_lookup(resolved, :users, value) ||
          safe_user(bot, value)
      when :channel
        resolved_lookup(resolved, :channels, value) || safe_channel(bot, value)
      when :role
        resolved_lookup(resolved, :roles, value)
      when :mentionable
        resolved_lookup(resolved, :members, value) ||
          resolved_lookup(resolved, :users, value) ||
          resolved_lookup(resolved, :roles, value) ||
          safe_user(bot, value)
      when :attachment
        resolved_lookup(resolved, :attachments, value)
      when :integer
        value.to_i
      when :number
        value.to_f
      when :boolean
        value ? true : false
      else
        value.to_s
      end
    end

    private

    def normalize_type(type)
      type = type.to_sym
      raise InvalidOptionError, "Unknown option type: #{type.inspect}" unless TYPES.key?(type)

      type
    end

    def choices_payload
      return nil if choices.nil?

      case choices
      when Hash
        choices.map { |name, value| { name: name.to_s, value: value } }
      when Array
        choices.map do |choice|
          if choice.is_a?(Hash)
            {
              name: (choice[:name] || choice["name"]).to_s,
              value: choice.key?(:value) ? choice[:value] : choice["value"],
              name_localizations: stringify_keys(choice[:name_localizations] || choice["name_localizations"])
            }.compact
          else
            { name: choice.to_s, value: choice }
          end
        end
      else
        Array(choices)
      end
    end

    def channel_types_payload
      return nil if channel_types.nil?

      Array(channel_types).map do |value|
        Discordrb::Channel::TYPES[value.to_sym] || value
      end
    end

    def validate_choices!
      return unless choices

      unless supports_choices?
        raise InvalidOptionError, "Option #{name.inspect} type #{type.inspect} does not support choices."
      end

      raise InvalidOptionError, "Option #{name.inspect} cannot use both choices and autocomplete." if autocomplete

      values = if choices.is_a?(Hash)
                 choices.values
               else
                 Array(choices).map do |c|
                   c.is_a?(Hash) ? (c[:value] || c["value"]) : c
                 end
               end
      raise InvalidOptionError, "Option #{name.inspect} can have at most 25 choices." if values.size > 25

      values.each do |value|
        next if type == :string && value.is_a?(String)
        next if type == :integer && value.is_a?(Integer)
        next if type == :number && value.is_a?(Numeric)

        raise InvalidOptionError, "Choice value #{value.inspect} does not match option type #{type.inspect}."
      end
    end

    def validate_autocomplete!
      return unless autocomplete

      return if supports_autocomplete?

      raise InvalidOptionError, "Option #{name.inspect} type #{type.inspect} does not support autocomplete."
    end

    def validate_lengths!
      return if min_length.nil? && max_length.nil?
      raise InvalidOptionError, "min_length and max_length are only valid for string options." unless type == :string

      raise InvalidOptionError, "min_length cannot be negative." if min_length&.negative?
      raise InvalidOptionError, "max_length must be positive." if max_length && max_length <= 0
      return unless min_length && max_length && min_length > max_length

      raise InvalidOptionError,
            "min_length cannot be greater than max_length."
    end

    def validate_values!
      return if min_value.nil? && max_value.nil?

      unless %i[integer number].include?(type)
        raise InvalidOptionError, "min_value and max_value are only valid for numeric options."
      end
      return unless min_value && max_value && min_value > max_value

      raise InvalidOptionError,
            "min_value cannot be greater than max_value."
    end

    def validate_channel_types!
      return if channel_types.nil?
      raise InvalidOptionError, "channel_types is only valid for channel options." unless type == :channel
    end

    def resolved_lookup(resolved, collection, value)
      return nil unless resolved

      hash = resolved.public_send(collection)
      hash[value.to_i] || hash[value]
    end

    def safe_user(bot, value)
      bot.user(value.to_i)
    rescue StandardError
      nil
    end

    def safe_channel(bot, value)
      bot.channel(value.to_i)
    rescue StandardError
      nil
    end

    def stringify_keys(hash)
      hash&.to_h { |key, value| [key.to_s, value] }
    end
  end
end
