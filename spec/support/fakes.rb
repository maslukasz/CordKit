# frozen_string_literal: true

# Minimal fake discordrb handler used in specs.
class FakeApplicationCommandHandler
  attr_reader :subcommands, :groups, :block

  def initialize(&block)
    @block = block
    @subcommands = {}
    @groups = {}
  end

  def subcommand(name, &block)
    @subcommands[name.to_sym] = block
  end

  def group(name)
    builder = FakeSubcommandBuilder.new
    yield builder
    @groups[name.to_sym] = builder.subcommands
  end
end

class FakeSubcommandBuilder
  attr_reader :subcommands

  def initialize
    @subcommands = {}
  end

  def subcommand(name, &block)
    @subcommands[name.to_sym] = block
  end
end

# Minimal fake discordrb interaction container used in specs.
class FakeContainer
  attr_reader :handlers, :application_commands

  HANDLER_METHODS = %i[
    ready button string_select user_select role_select mentionable_select channel_select modal_submit autocomplete
  ].freeze

  def initialize
    @handlers = []
    @application_commands = {}
  end

  HANDLER_METHODS.each do |method_name|
    define_method(method_name) do |*args, &block|
      handler = [method_name, args, block]
      @handlers << handler
      handler
    end
  end

  def application_command(name, _attributes = {}, &block)
    return @application_commands[name] unless block

    @application_commands[name] = FakeApplicationCommandHandler.new(&block)
  end

  def remove_application_command_handler(name)
    @application_commands.delete(name)
  end

  def remove_handler(handler)
    @handlers.delete(handler)
  end

  def token = "fake-token"
  def shard_key = nil
  def servers = {}
  def profile = nil
end

# Records interaction API calls.
class FakeInteraction
  attr_reader :calls

  def initialize
    @calls = []
  end

  def respond(**kwargs)
    @calls << [:respond, kwargs]
    :response
  end

  def defer(**kwargs)
    @calls << [:defer, kwargs]
    nil
  end

  def edit_response(**kwargs)
    @calls << [:edit_response, kwargs]
    :edited
  end

  def send_message(**kwargs)
    @calls << [:send_message, kwargs]
    :sent
  end

  def update_message(**kwargs)
    @calls << [:update_message, kwargs]
    :updated
  end

  def defer_update
    @calls << [:defer_update, {}]
    nil
  end

  def show_modal(**kwargs)
    @calls << [:show_modal, kwargs]
    nil
  end

  def delete_response
    @calls << [:delete_response, {}]
    nil
  end

  def id = 1
  def token = "interaction-token"
  def application_id = 2
  def application_permissions = nil
  def server_locale = nil
  def max_attachment_size = 1024
end

# Minimal fake interaction event.
class FakeEvent
  attr_reader :interaction, :options, :resolved, :user, :server, :channel, :message, :custom_id, :components

  def initialize(interaction: FakeInteraction.new, options: {}, resolved: nil, user: nil, server: nil, channel: nil,
                 custom_id: nil, message: nil, modal_values: {}, components: [])
    @interaction = interaction
    @options = options
    @resolved = resolved
    @user = user || Struct.new(:id).new(10)
    @server = server
    @channel = channel
    @custom_id = custom_id
    @message = message
    @modal_values = modal_values
    @components = components
  end

  def server_id = server&.id
  def channel_id = channel&.id
  def user_locale = "en-US"
  def context = 0
  def bot = nil
  def command_name = :demo
  def subcommand = nil
  def subcommand_group = nil

  def value(custom_id) = @modal_values[custom_id]
  def values(custom_id = nil) = custom_id ? @modal_values[custom_id] : @modal_values.values
  def attachments(_custom_id) = []
end

def fake_runtime(container: FakeContainer.new, **options)
  CordKit::Runtime.new(container, sync: false, **options)
end
