# frozen_string_literal: true

RSpec.describe CordKit::Check do
  it "requires a block" do
    expect { described_class.new }.to raise_error(ArgumentError, /requires a block/)
  end

  it "passes when the block returns a truthy value" do
    check = described_class.new { |_ctx| true }

    expect(check.call(double)).to be(true)
  end

  it "raises CheckFailed with the configured message" do
    check = described_class.new(message: "Nope") { |_ctx| false }

    expect { check.call(double) }.to raise_error(CordKit::CheckFailed, "Nope")
  end

  it "wraps unexpected errors in CheckFailed" do
    check = described_class.new(message: "Broken") { |_ctx| raise "boom" }

    expect { check.call(double) }.to raise_error(CordKit::CheckFailed, "Broken")
  end
end

RSpec.describe CordKit::Checks do
  let(:server) { double(id: 1, owner: double(id: 4242)) }
  let(:config) { double(owner_ids: [777]) }

  def build_context(server: nil, member: nil, bot_member: nil, user: nil, channel_id: nil, channel: nil)
    double(
      server: server,
      member: member,
      bot_member: bot_member,
      user: user || double(id: 10),
      channel_id: channel_id,
      channel: channel,
      config: config
    )
  end

  def build_member(id: 10, roles: [], server: nil)
    double(id: id, roles: roles, server: server)
  end

  def build_role(id: 1, name: "Mod", administrator: false, bits: 0)
    double(id: id, name: name, permissions: double(administrator: administrator, bits: bits))
  end

  describe ".guild_only" do
    it "passes in a server" do
      expect(described_class.guild_only.call(build_context(server: server))).to be(true)
    end

    it "rejects in DMs" do
      expect { described_class.guild_only.call(build_context) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".dm_only" do
    it "passes in DMs" do
      expect(described_class.dm_only.call(build_context)).to be(true)
    end

    it "rejects in a server" do
      expect { described_class.dm_only.call(build_context(server: server)) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".users" do
    it "allows listed users" do
      check = described_class.users(10)

      expect(check.call(build_context(user: double(id: 10)))).to be(true)
    end

    it "rejects other users" do
      check = described_class.users(10)

      expect { check.call(build_context(user: double(id: 11))) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".servers" do
    it "allows listed servers" do
      check = described_class.servers(1)

      expect(check.call(build_context(server: server))).to be(true)
    end

    it "rejects other servers" do
      check = described_class.servers(2)

      expect { check.call(build_context(server: server)) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".channels" do
    it "allows listed channels" do
      check = described_class.channels(5)

      expect(check.call(build_context(channel_id: 5))).to be(true)
    end

    it "rejects other channels" do
      check = described_class.channels(5)

      expect { check.call(build_context(channel_id: 6)) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".owner_only" do
    it "uses ctx.config.owner_ids by default" do
      check = described_class.owner_only

      expect(check.call(build_context(user: double(id: 777)))).to be(true)
      expect { check.call(build_context(user: double(id: 1))) }.to raise_error(CordKit::CheckFailed)
    end

    it "accepts an explicit list" do
      check = described_class.owner_only(42)

      expect(check.call(build_context(user: double(id: 42)))).to be(true)
    end
  end

  describe ".user_permissions" do
    it "passes when the member holds every permission" do
      role = build_role(bits: Discordrb::Permissions.bits(%i[manage_server ban_members]))
      member = build_member(roles: [role])
      check = described_class.user_permissions(:manage_server, :ban_members)

      expect(check.call(build_context(server: server, member: member))).to be(true)
    end

    it "rejects when a permission is missing" do
      role = build_role(bits: Discordrb::Permissions.bits([:manage_server]))
      member = build_member(roles: [role])
      check = described_class.user_permissions(:ban_members)

      expect { check.call(build_context(server: server, member: member)) }
        .to raise_error(CordKit::CheckFailed)
    end

    it "supports any: mode" do
      role = build_role(bits: Discordrb::Permissions.bits([:manage_server]))
      member = build_member(roles: [role])
      check = described_class.user_permissions(:ban_members, :manage_server, any: true)

      expect(check.call(build_context(server: server, member: member))).to be(true)
    end

    it "grants everything to administrators" do
      role = build_role(administrator: true)
      member = build_member(roles: [role])
      check = described_class.user_permissions(:ban_members)

      expect(check.call(build_context(server: server, member: member))).to be(true)
    end

    it "grants everything to the server owner" do
      member = build_member(id: 4242, server: server)
      check = described_class.user_permissions(:ban_members)

      expect(check.call(build_context(server: server, member: member))).to be(true)
    end

    it "rejects members outside a server" do
      check = described_class.user_permissions(:ban_members)

      expect { check.call(build_context) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".bot_permissions" do
    it "checks the bot member" do
      role = build_role(bits: Discordrb::Permissions.bits([:manage_server]))
      bot_member = build_member(roles: [role])
      check = described_class.bot_permissions(:manage_server)

      expect(check.call(build_context(server: server, bot_member: bot_member))).to be(true)
    end
  end

  describe ".roles" do
    it "matches roles by id" do
      member = build_member(roles: [build_role(id: 5, name: "VIP")])
      check = described_class.roles(5)

      expect(check.call(build_context(member: member))).to be(true)
    end

    it "matches roles by name" do
      member = build_member(roles: [build_role(id: 5, name: "VIP")])
      check = described_class.roles("VIP")

      expect(check.call(build_context(member: member))).to be(true)
    end

    it "rejects when no role matches" do
      member = build_member(roles: [build_role(id: 5, name: "VIP")])
      check = described_class.roles(6)

      expect { check.call(build_context(member: member)) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".nsfw" do
    it "passes in an NSFW channel" do
      channel = double(nsfw?: true)

      expect(described_class.nsfw.call(build_context(channel: channel))).to be(true)
    end

    it "rejects elsewhere" do
      channel = double(nsfw?: false)

      expect { described_class.nsfw.call(build_context(channel: channel)) }.to raise_error(CordKit::CheckFailed)
    end
  end

  describe ".role_permissions" do
    it "returns zero when the member cannot be inspected" do
      member = build_member(roles: [build_role])
      allow(member).to receive(:roles).and_raise("broken")

      expect(described_class.role_permissions(member)).to eq(0)
    end
  end
end
