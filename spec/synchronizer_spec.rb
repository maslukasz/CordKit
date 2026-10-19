# frozen_string_literal: true

require "json"

RSpec.describe CordKit::Synchronizer do
  let(:container) { FakeContainer.new }
  let(:runtime) { fake_runtime(container: container) }
  let(:plugin) do
    Class.new(CordKit::Plugin) do
      plugin_name :sync_spec
      command :ping, "Ping" do |ctx|
        ctx.respond "pong"
      end
    end
  end

  before do
    allow(container).to receive(:profile).and_return(double(id: 4242))
    runtime.register_plugin(plugin)
  end

  describe "#sync!" do
    it "overwrites global commands in replace mode" do
      expect(Discordrb::API::Application).to receive(:bulk_overwrite_global_commands)
        .with("fake-token", 4242, [hash_including(name: "ping")])

      runtime.synchronizer.sync!(scope: :global, mode: :replace)
    end

    it "overwrites guild commands for each configured guild" do
      allow(Discordrb::API::Application).to receive(:bulk_overwrite_guild_commands).and_return("ok")

      result = runtime.synchronizer.sync!(scope: :guild, guild_ids: [111, 222])

      expect(result.keys).to contain_exactly(111, 222)
    end

    it "raises for an unknown scope" do
      expect { runtime.synchronizer.sync!(scope: :everywhere) }
        .to raise_error(CordKit::ConfigurationError, /Unknown command scope/)
    end

    it "raises when guild scope has no guild IDs" do
      expect { runtime.synchronizer.sync!(scope: :guild) }
        .to raise_error(CordKit::ConfigurationError, /No guild IDs/)
    end
  end

  describe "#sync_global!" do
    it "merges existing commands in merge mode" do
      existing = JSON.generate([
                                 { "id" => "1", "name" => "legacy", "description" => "old",
                                   "application_id" => "4242", "guild_id" => "1" }
                               ])
      allow(Discordrb::API::Application).to receive(:get_global_commands).and_return(existing)
      received = nil
      allow(Discordrb::API::Application).to receive(:bulk_overwrite_global_commands) do |_token, _app, payloads|
        received = payloads
        "ok"
      end

      runtime.synchronizer.sync_global!(:merge)

      expect(received.first).to eq("name" => "legacy", "description" => "old")
      expect(received.last).to include(name: "ping")
    end
  end

  describe "application id lookup" do
    it "falls back to bot_application when the profile is unavailable" do
      allow(container).to receive(:profile).and_raise("no cache")
      allow(container).to receive(:bot_application).and_return(double(id: 99))
      expect(Discordrb::API::Application).to receive(:bulk_overwrite_global_commands)
        .with("fake-token", 99, anything)

      runtime.synchronizer.sync!(scope: :global)
    end

    it "raises when no application id can be resolved" do
      allow(container).to receive(:profile).and_raise("no cache")
      allow(container).to receive(:bot_application).and_return(nil)

      expect { runtime.synchronizer.sync!(scope: :global) }
        .to raise_error(CordKit::ConfigurationError, /application ID/)
    end
  end
end
