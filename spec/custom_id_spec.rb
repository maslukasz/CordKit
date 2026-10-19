# frozen_string_literal: true

RSpec.describe CordKit::CustomId do
  let(:store) { CordKit::StateStore::Memory.new(default_ttl: 60) }

  describe ".build" do
    it "builds a bare route ID" do
      expect(described_class.build(plugin: :tickets, route: :open)).to eq("dk1:tickets:open")
    end

    it "inlines small JSON payloads" do
      id = described_class.build(plugin: :tickets, route: :open, data: { id: 1 })
      expect(id).to start_with("dk1:tickets:open:d.")
    end

    it "falls back to the state store for long payloads" do
      id = described_class.build(plugin: :tickets, route: :open, data: { value: "x" * 120 }, store: store)
      expect(id).to include(":s.")
      expect(id.bytesize).to be <= described_class::MAX_LENGTH
    end

    it "raises when no store is available and the payload does not fit" do
      expect do
        described_class.build(plugin: :tickets, route: :open, data: { value: "x" * 120 })
      end.to raise_error(CordKit::InvalidCustomIdError)
    end

    it "rejects invalid plugin names" do
      expect { described_class.build(plugin: "Bad Name", route: :open) }
        .to raise_error(CordKit::InvalidCustomIdError)
    end
  end

  describe ".parse" do
    it "parses a bare route" do
      parsed = described_class.parse("dk1:tickets:open")
      expect(parsed.plugin).to eq(:tickets)
      expect(parsed.route).to eq("open")
      expect(parsed.data).to be_nil
    end

    it "parses inline data" do
      parsed = described_class.parse(described_class.build(plugin: :tickets, route: :open, data: { id: 42 }))
      expect(parsed.data).to eq("id" => 42)
    end

    it "parses a state token" do
      id = described_class.build(plugin: :tickets, route: :open, data: { value: "x" * 120 }, store: store)
      parsed = described_class.parse(id)
      expect(parsed.token).not_to be_nil
      expect(described_class.parse("other:id")).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end
  end
end
