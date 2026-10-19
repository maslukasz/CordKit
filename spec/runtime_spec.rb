# frozen_string_literal: true

RSpec.describe CordKit::Runtime do
  let(:container) { FakeContainer.new }
  let(:runtime) { described_class.new(container, sync: false) }

  let(:plugin_class) do
    Class.new(CordKit::Plugin) do
      plugin_name :runtime_spec
      command :ping, "Ping" do |ctx|
        ctx.respond("pong")
      end
    end
  end

  let(:subcommand_plugin) do
    Class.new(CordKit::Plugin) do
      plugin_name :runtime_subcommands_spec
      command :config, "Config" do
        subcommand :get, "Get" do
          run { |ctx| ctx.respond("value") }
        end
      end
    end
  end

  let(:group_plugin) do
    Class.new(CordKit::Plugin) do
      plugin_name :runtime_groups_spec
      command :admin, "Admin" do
        subcommand_group :roles, "Roles" do
          subcommand :set, "Set" do
            run { |ctx| ctx.respond("set") }
          end
        end
      end
    end
  end

  it "registers commands and creates discordrb handlers" do
    runtime.register_plugin(plugin_class)

    expect(runtime.command_registry.payloads).to contain_exactly(
      include(name: "ping", description: "Ping")
    )
    expect(container.application_commands).to have_key("ping")
  end

  it "binds subcommands and groups" do
    runtime.register_plugin(subcommand_plugin)
    runtime.register_plugin(group_plugin)

    expect(container.application_commands["config"].subcommands).to have_key(:get)
    expect(container.application_commands["admin"].groups).to have_key(:roles)
    expect(container.application_commands["admin"].groups[:roles]).to have_key(:set)
  end

  it "returns the existing instance when a plugin is registered twice" do
    first = runtime.register_plugin(plugin_class)
    second = runtime.register_plugin(plugin_class)

    expect(second).to be(first)
  end

  it "rejects duplicate command names" do
    runtime.register_plugin(plugin_class)

    duplicate = Class.new(CordKit::Plugin) do
      plugin_name :runtime_duplicate_spec
      command :ping, "Another ping" do |ctx|
        ctx.respond("pong")
      end
    end

    expect { runtime.register_plugin(duplicate) }.to raise_error(CordKit::DuplicateCommandError)
  end

  it "unloads plugins" do
    runtime.register_plugin(plugin_class)
    expect(runtime.unload_plugin(:runtime_spec)).to be(true)

    expect(runtime.plugins).to be_empty
    expect(runtime.command_registry.size).to eq(0)
    expect(container.application_commands).not_to have_key("ping")
  end

  it "loads dependencies" do
    dependency = Class.new(CordKit::Plugin) do
      plugin_name :runtime_dependency_spec
      command :dep, "Dependency" do |ctx|
        ctx.respond("dep")
      end
    end

    dependent = Class.new(CordKit::Plugin) do
      plugin_name :runtime_dependent_spec
      depends_on :runtime_dependency_spec
    end

    runtime.register_plugin(dependent)
    expect(runtime.plugins.keys).to include(:runtime_dependency_spec, :runtime_dependent_spec)
  end

  it "removes global handlers when stopped" do
    runtime # ensure the runtime has installed its handlers
    handler_count = container.handlers.size
    runtime.stop

    expect(container.handlers.size).to be < handler_count
  end
end
