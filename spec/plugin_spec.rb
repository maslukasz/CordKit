# frozen_string_literal: true

RSpec.describe CordKit::Plugin do
  class SpecDerivedPlugin < CordKit::Plugin; end

  it "derives a plugin name from the class name" do
    expect(SpecDerivedPlugin.plugin_name).to eq(:spec_derived_plugin)
  end

  it "defines simple commands" do
    plugin = Class.new(described_class) do
      plugin_name :simple_spec
      command :ping, "Ping" do |ctx|
        ctx.respond("pong")
      end
    end

    command = plugin.commands.first
    expect(command.name).to eq("ping")
    expect(command.description).to eq("Ping")
    expect(command.handler).to be_a(Proc)
  end

  it "allows omitting the command description" do
    plugin = Class.new(described_class) do
      plugin_name :no_description_spec
      command :daily_reward do |ctx|
        ctx.respond("ok")
      end
    end

    expect(plugin.commands.first.description).to eq("Daily reward command")
  end

  it "defines advanced commands with options and subcommands" do
    plugin = Class.new(described_class) do
      plugin_name :advanced_spec
      command :config, "Config" do
        subcommand :get, "Get" do
          option :key, :string, "Key", required: true
          run { |ctx| ctx.respond("ok") }
        end
      end
    end

    command = plugin.commands.first
    expect(command.subcommands.keys).to eq([:get])
    expect(command.subcommands[:get].options.first.name).to eq("key")
  end

  it "registers component handlers with routes and raw custom IDs" do
    plugin = Class.new(described_class) do
      plugin_name :components_spec
      button :open do |ctx|
        ctx.respond("open")
      end
      button "legacy" do |ctx|
        ctx.respond("legacy")
      end
    end

    definitions = plugin.component_definitions
    expect(definitions.map(&:route)).to contain_exactly("open", nil)
    expect(definitions.map(&:matcher)).to include("legacy")
  end

  it "normalizes dependency names" do
    plugin = Class.new(described_class) do
      plugin_name :deps_spec
      depends_on :other
    end

    expect(plugin.dependencies).to eq([:other])
  end
end
