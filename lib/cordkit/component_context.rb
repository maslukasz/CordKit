# frozen_string_literal: true

module CordKit
  # Context passed to button and select handlers.
  class ComponentContext < Context
    # @return [String]
    def custom_id
      event.custom_id
    end

    # @return [Discordrb::Interactions::Message, nil]
    def message
      event.message
    end

    # @return [Object, nil]
    def values
      return nil unless event.respond_to?(:values)

      event.values
    end

    # Returns inline or stored state from the custom ID.
    # @return [Object, nil]
    def state
      return @state if defined?(@state)

      parsed = params[:parsed] || CustomId.parse(custom_id)
      @state = if parsed&.token
                 state_store.read(parsed.token)
               else
                 parsed&.data
               end
    end

    # Updates the message that contains this component.
    # @return [Object, nil]
    def update(content = nil, **kwargs, &)
      kwargs = prepare_response(kwargs, &)
      kwargs[:content] = content unless content.nil?

      @response_mutex.synchronize do
        result = interaction.update_message(**filter_kwargs(kwargs, :update_message))
        @acknowledged = true
        @responded = true
        result
      end
    end
    alias update_message update

    # Acknowledges the component without changing the message.
    # @return [nil]
    def defer_update
      @response_mutex.synchronize do
        return nil if @acknowledged

        interaction.defer_update
        @acknowledged = true
        @deferred = true
      end
      nil
    end
  end
end
