# frozen_string_literal: true

RSpec.describe CordKit::StateStore::Memory do
  subject(:store) { described_class.new(default_ttl: 60) }

  it "writes and reads values" do
    key = store.write("hello")
    expect(store.read(key)).to eq("hello")
    expect(store.exist?(key)).to be(true)
  end

  it "deletes values" do
    key = store.write("hello")
    expect(store.delete(key)).to be(true)
    expect(store.read(key)).to be_nil
  end

  it "expires values" do
    key = store.write("hello", ttl: 0.01)
    sleep 0.02
    expect(store.read(key)).to be_nil
  end

  it "fetches through a block once" do
    calls = 0
    value = store.fetch("key") do
      calls += 1
      "value"
    end
    expect(value).to eq("value")
    expect(store.fetch("key") { "other" }).to eq("value")
    expect(calls).to eq(1)
  end

  it "trims entries over the limit" do
    small = described_class.new(default_ttl: 60, max_entries: 2)
    keys = Array.new(3) { |i| small.write(i) }
    expect(keys.map { |key| small.read(key) }).to eq([nil, 1, 2])
  end
end
