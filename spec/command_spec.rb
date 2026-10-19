# frozen_string_literal: true

RSpec.describe CordKit::Command do
  let(:plugin_class) do
    Class.new(CordKit::Plugin) do
      def self.name = "TestPlugin"
    end
  end

  def build(&block)
    builder = CordKit::CommandBuilder.new(:demo, description: "Demo", plugin_class: plugin_class)
    builder.instance_eval(&block)
    builder.to_command
  end

  it "builds a simple command payload" do
    command = build do
      option :name, :string, "Name", required: true
      run { |ctx| ctx.respond("hi") }
    end

    expect(command.to_h).to include(
      name: "demo",
      description: "Demo",
      type: 1,
      options: [{ type: 3, name: "name", description: "Name", required: true }]
    )
  end

  it "builds subcommand and group payloads" do
    command = build do
      subcommand :get, "Get" do
        option :key, :string, "Key", required: true
        run { |ctx| ctx.respond("ok") }
      end
      subcommand_group :admin, "Admin" do
        subcommand :set, "Set" do
          run { |ctx| ctx.respond("ok") }
        end
      end
    end

    payload = command.to_h
    expect(payload[:options].size).to eq(2)
    expect(payload[:options][0]).to include(type: 1, name: "get")
    expect(payload[:options][1]).to include(type: 2, name: "admin")
  end

  it "requires a handler for leaf commands" do
    command = build { option :name, :string, "Name" }
    expect { command.validate! }.to raise_error(CordKit::InvalidCommandError)
  end

  it "rejects mixed subcommands and options" do
    command = build do
      option :name, :string, "Name"
      subcommand(:get, "Get") { |ctx| ctx.respond("ok") }
    end
    expect { command.validate! }.to raise_error(CordKit::InvalidCommandError)
  end

  it "rejects required options after optional ones" do
    command = build do
      option :first, :string, "First"
      option :second, :string, "Second", required: true
      run { |ctx| ctx.respond("ok") }
    end
    expect { command.validate! }.to raise_error(CordKit::InvalidCommandError)
  end

  it "marks autocomplete options" do
    command = build do
      option :query, :string, "Query"
      autocomplete(:query) { |ctx| ctx.choices(%w[a b]) }
      run { |ctx| ctx.respond("ok") }
    end
    command.validate!
    expect(command.options.first).to be_autocomplete
  end

  it "normalizes options using resolved data" do
    resolved = Discordrb::Events::InteractionCreateEvent::Resolved.new({}, { 1 => :server_member }, {}, {}, {}, {})
    raw_event = Struct.new(:options, :resolved, :bot).new({ "user" => "1" }, resolved, :bot)
    command = build do
      option :user, :user, "User"
      run { |ctx| ctx.respond("ok") }
    end

    expect(command.normalize_options(raw_event)).to eq(user: :server_member)
  end

  it "derives a description when none is provided" do
    builder = CordKit::CommandBuilder.new(:daily_reward, plugin_class: plugin_class)
    builder.run { |ctx| ctx.respond("ok") }

    expect(builder.to_command.description).to eq("Daily reward command")
  end
end
