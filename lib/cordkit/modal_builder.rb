# frozen_string_literal: true

module CordKit
  # A discordrb modal builder with route-aware field custom IDs.
  #
  # @example
  #   ctx.show_modal("Open a ticket", route: :ticket_create) do |m|
  #     m.text_input :title, label: "Title", required: true
  #     m.text_input :body, label: "Describe the issue", style: :paragraph
  #   end
  class ModalBuilder < Discordrb::Webhooks::Modal
    # @return [Symbol]
    attr_reader :plugin_name

    # @return [CordKit::Runtime]
    attr_reader :runtime

    def initialize(plugin:, runtime:, &block)
      @plugin_name = plugin.to_sym
      @runtime = runtime
      super(&nil)
      yield self if block
    end

    # @param route [Symbol, String]
    # @param data [Object, nil]
    # @return [String]
    def custom_id(route, data: nil)
      CustomId.build(plugin: plugin_name, route: route, data: data)
    end

    # Adds a label component.
    # @return [CordKit::ModalBuilder::LabelBuilder]
    def label(label: nil, id: nil, description: nil, &block)
      builder = LabelBuilder.new(modal: self, label: label, id: id, description: description)
      if block
        block.arity.zero? ? builder.instance_eval(&block) : yield(builder)
      end
      @components << builder.to_h
      builder
    end

    # Convenience method: adds a label containing a text input.
    # @return [CordKit::ModalBuilder::LabelBuilder]
    def text_input(route = nil, label:, custom_id: nil, **options, &block)
      self.label(label: label) do |builder|
        builder.text_input(route, custom_id: custom_id, **options, &block)
      end
    end
    alias field text_input

    # Convenience method: adds a label containing a string select.
    # @return [CordKit::ModalBuilder::LabelBuilder]
    def string_select(route = nil, label:, custom_id: nil, **options, &block)
      self.label(label: label) do |builder|
        builder.string_select(route, custom_id: custom_id, **options, &block)
      end
    end
    alias select string_select

    # Convenience method: adds a label containing a user select.
    def user_select(route = nil, label:, custom_id: nil, **options)
      self.label(label: label) { |builder| builder.user_select(route, custom_id: custom_id, **options) }
    end

    # Convenience method: adds a label containing a role select.
    def role_select(route = nil, label:, custom_id: nil, **options)
      self.label(label: label) { |builder| builder.role_select(route, custom_id: custom_id, **options) }
    end

    # Convenience method: adds a label containing a mentionable select.
    def mentionable_select(route = nil, label:, custom_id: nil, **options)
      self.label(label: label) { |builder| builder.mentionable_select(route, custom_id: custom_id, **options) }
    end

    # Convenience method: adds a label containing a channel select.
    def channel_select(route = nil, label:, custom_id: nil, **options)
      self.label(label: label) { |builder| builder.channel_select(route, custom_id: custom_id, **options) }
    end

    # Convenience method: adds a label containing a file upload.
    def file_upload(route = nil, label:, custom_id: nil, **options)
      self.label(label: label) { |builder| builder.file_upload(route, custom_id: custom_id, **options) }
    end

    # A label builder with route-aware field custom IDs.
    class LabelBuilder < Discordrb::Webhooks::Modal::LabelBuilder
      def initialize(modal:, label: nil, id: nil, description: nil)
        @modal = modal
        super(label: label, id: id, description: description)
      end

      # Adds a text input field.
      # @return [Hash]
      def text_input(route = nil, style: :short, custom_id: nil, **options)
        super(style: style, custom_id: resolve(route, custom_id), **options)
      end

      # Adds a string select field.
      # @return [Hash]
      def string_select(route = nil, custom_id: nil, **options, &block)
        super(custom_id: resolve(route, custom_id), **options, &block)
      end
      alias select_menu string_select
      alias select string_select

      # Adds a user select field.
      # @return [Hash]
      def user_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a role select field.
      # @return [Hash]
      def role_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a mentionable select field.
      # @return [Hash]
      def mentionable_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a channel select field.
      # @return [Hash]
      def channel_select(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a file upload field.
      # @return [Hash]
      def file_upload(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a checkbox field.
      # @return [Hash]
      def checkbox(route = nil, custom_id: nil, **options)
        super(custom_id: resolve(route, custom_id), **options)
      end

      # Adds a radio group field.
      # @return [Hash]
      def radio_group(route = nil, custom_id: nil, **options, &block)
        super(custom_id: resolve(route, custom_id), **options, &block)
      end

      # Adds a checkbox group field.
      # @return [Hash]
      def checkbox_group(route = nil, custom_id: nil, **options, &block)
        super(custom_id: resolve(route, custom_id), **options, &block)
      end

      private

      def resolve(route, custom_id)
        return custom_id if custom_id

        case route
        when Symbol
          @modal.custom_id(route)
        when String
          route
        when nil
          raise ArgumentError, "A route or custom_id is required for this modal field."
        else
          raise ArgumentError, "Modal field route must be a Symbol or String."
        end
      end
    end
  end
end
