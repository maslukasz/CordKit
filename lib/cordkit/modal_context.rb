# frozen_string_literal: true

module CordKit
  # Context passed to modal submission handlers.
  class ModalContext < ComponentContext
    # Reads a text input value by route or raw custom ID.
    # @param name [Symbol, String]
    # @return [String, nil]
    def value(name)
      event.value(field_custom_id(name))
    end
    alias field value

    # Reads selected values by route or raw custom ID.
    #
    # Without an argument, returns a hash of all submitted components.
    # @param name [Symbol, String, nil]
    # @return [Hash, Array, nil]
    def values(name = nil)
      return all_values if name.nil?

      event.values(field_custom_id(name))
    end

    # Reads uploaded attachments by route or raw custom ID.
    # @param name [Symbol, String]
    # @return [Array<Discordrb::Attachment>]
    def attachments(name)
      event.attachments(field_custom_id(name))
    end

    # @param name [Symbol, String]
    # @return [Boolean]
    def field?(name)
      !value(name).nil? || !values(name).nil?
    end

    private

    def field_custom_id(name)
      name.is_a?(Symbol) ? route_custom_id(name) : name.to_s
    end

    def all_values
      event.components.each_with_object({}) do |component, result|
        next unless component.respond_to?(:custom_id)

        result[component.custom_id] = if component.respond_to?(:values)
                                        component.values
                                      elsif component.respond_to?(:value)
                                        component.value
                                      end
      end
    end
  end
end
