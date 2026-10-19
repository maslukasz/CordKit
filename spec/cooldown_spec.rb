# frozen_string_literal: true

RSpec.describe CordKit::Cooldown do
  let(:context) { double(user: double(id: 1), server: double(id: 2)) }

  it "allows the first use and blocks the second" do
    cooldown = described_class.new(10, per: :user)

    expect { cooldown.check!(context, "demo") }.not_to raise_error
    expect { cooldown.check!(context, "demo") }.to raise_error(CordKit::CooldownError)
  end

  it "scopes buckets per user" do
    cooldown = described_class.new(10, per: :user)
    other = double(user: double(id: 3), server: double(id: 2))

    cooldown.check!(context, "demo")
    expect { cooldown.check!(other, "demo") }.not_to raise_error
  end

  it "exposes remaining time" do
    cooldown = described_class.new(10, per: :user)
    cooldown.check!(context, "demo")

    expect(cooldown.remaining(context, "demo")).to be > 0
  end

  it "rejects unknown scopes" do
    expect { described_class.new(10, per: :channel) }.to raise_error(CordKit::ConfigurationError)
  end
end
