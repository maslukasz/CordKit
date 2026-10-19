# frozen_string_literal: true

RSpec.describe CordKit::Configuration do
  subject(:config) { described_class.new }

  it "defaults to development" do
    expect(config.environment).to eq(:development)
    expect(config).to be_development
  end

  it "resolves :auto scope to :guild in development" do
    expect(config.effective_command_scope).to eq(:guild)
  end

  it "resolves :auto scope to :global in production" do
    config.environment = :production
    expect(config.effective_command_scope).to eq(:global)
  end

  it "normalizes guild ids" do
    config.guild_ids = %w[1 2]
    expect(config.effective_guild_ids).to eq([1, 2])
  end
end
