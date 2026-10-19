# frozen_string_literal: true

require "discordrb"
require "discordrb/webhooks"

require "cordkit/version"
require "cordkit/errors"
require "cordkit/configuration"
require "cordkit/state_store"
require "cordkit/state_store/memory"
require "cordkit/custom_id"
require "cordkit/cooldown"
require "cordkit/checks"
require "cordkit/option_definition"
require "cordkit/command"
require "cordkit/command_builder"
require "cordkit/command_registry"
require "cordkit/plugin"
require "cordkit/view"
require "cordkit/modal_builder"
require "cordkit/context"
require "cordkit/component_context"
require "cordkit/modal_context"
require "cordkit/autocomplete_context"
require "cordkit/router"
require "cordkit/synchronizer"
require "cordkit/runtime"
require "cordkit/bot"

# CordKit is a thin, beginner-friendly layer on top of discordrb.
module CordKit
  class << self
    # Attaches a CordKit runtime to an existing discordrb bot.
    #
    # @param bot [Discordrb::Bot]
    # @param options [Hash] CordKit configuration options.
    # @yieldparam config [CordKit::Configuration]
    # @return [CordKit::Runtime]
    def attach(bot, **options, &)
      runtime = Runtime.new(bot, **options, &)
      bot.instance_variable_set(:@cordkit, runtime)
      runtime
    end

    # @param bot [Discordrb::Bot]
    # @return [CordKit::Runtime, nil]
    def runtime_for(bot)
      bot.instance_variable_get(:@cordkit) if bot.instance_variable_defined?(:@cordkit)
    end
  end
end
