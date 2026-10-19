# frozen_string_literal: true

module CordKit
  # Context passed to autocomplete handlers.
  class AutocompleteContext < Context
    # @return [String, nil]
    def focused
      event.focused
    end
    alias focused_option focused

    # @return [Object, nil]
    def query
      return nil unless focused

      event.options[focused] || event.options[focused.to_sym]
    end
    alias value query

    # Responds with autocomplete choices.
    #
    # @param list [Array, Hash]
    # @return [nil]
    def choices(list)
      @response_mutex.synchronize do
        return nil if @acknowledged

        event.respond(choices: normalize_choices(list))
        @acknowledged = true
        @responded = true
      end
      nil
    end
    alias respond choices

    private

    def normalize_choices(list)
      return [] if list.nil?

      choices = case list
                when Hash
                  list.map { |name, value| { name: name.to_s, value: value } }
                when Array
                  list.map do |choice|
                    case choice
                    when Hash
                      name = choice[:name] || choice["name"]
                      value = choice.key?(:value) ? choice[:value] : choice["value"]
                      { name: name.to_s, value: value }
                    when Array
                      { name: choice.first.to_s, value: choice.last }
                    else
                      { name: choice.to_s, value: choice.to_s }
                    end
                  end
                else
                  [{ name: list.to_s, value: list.to_s }]
                end

      choices.first(25).map do |choice|
        {
          name: truncate(choice[:name], 100),
          value: truncate(choice[:value], 100)
        }
      end
    end

    def truncate(value, limit)
      return value if value.is_a?(Numeric)

      value.to_s[0, limit]
    end
  end
end
