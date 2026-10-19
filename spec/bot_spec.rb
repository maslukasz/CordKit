# frozen_string_literal: true

RSpec.describe CordKit::Bot do
  around do |example|
    original_token = ENV.fetch("DISCORD_TOKEN", nil)
    original_bot_token = ENV.fetch("DISCORD_BOT_TOKEN", nil)
    example.run
  ensure
    ENV["DISCORD_TOKEN"] = original_token
    ENV["DISCORD_BOT_TOKEN"] = original_bot_token
  end

  it "creates an attached CordKit runtime" do
    ENV["DISCORD_TOKEN"] = "fake-token"

    bot = described_class.new

    expect(bot.cordkit).to be_a(CordKit::Runtime)
  end

  it "falls back to DISCORD_BOT_TOKEN" do
    ENV.delete("DISCORD_TOKEN")
    ENV["DISCORD_BOT_TOKEN"] = "fake-token"

    expect(described_class.new.cordkit).to be_a(CordKit::Runtime)
  end

  it "raises when no token is available" do
    ENV.delete("DISCORD_TOKEN")
    ENV.delete("DISCORD_BOT_TOKEN")

    expect { described_class.new }.to raise_error(RuntimeError, /Token string is empty/)
  end

  it "reads CordKit options from top level keywords" do
    ENV["DISCORD_TOKEN"] = "fake-token"

    bot = described_class.new(guild_ids: [123], sync: false)

    expect(bot.cordkit.config.guild_ids).to eq([123])
    expect(bot.cordkit.config.sync).to be(false)
  end
end
