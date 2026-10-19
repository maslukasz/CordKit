# frozen_string_literal: true

RSpec.describe CordKit::Context do
  let(:runtime) { fake_runtime }
  let(:plugin) { double(plugin_name: :tickets) }
  let(:plugin_class) do
    Class.new(CordKit::Plugin) do
      plugin_name :context_spec
    end
  end
  let(:command) do
    CordKit::Command.new(
      plugin_class: plugin_class,
      name: :demo,
      description: "Demo",
      handler: proc { |ctx| ctx.respond("ok") }
    )
  end
  let(:interaction) { FakeInteraction.new }
  let(:event) { FakeEvent.new(interaction: interaction) }
  subject(:context) do
    described_class.new(runtime: runtime, event: event, plugin: plugin, command: command)
  end

  it "sends the first response through the initial response" do
    context.respond("hello")

    expect(interaction.calls).to eq([[:respond, { content: "hello" }]])
  end

  it "sends later responses as follow-ups" do
    context.respond("hello")
    context.respond("again")

    expect(interaction.calls.last).to eq([:send_message, { content: "again" }])
  end

  it "edits the deferred response" do
    context.defer
    context.respond("done")

    expect(interaction.calls.first).to eq([:defer, { ephemeral: false }])
    expect(interaction.calls.last).to eq([:edit_response, { content: "done" }])
  end

  it "supports ephemeral responses" do
    context.respond("secret", ephemeral: true)

    expect(interaction.calls.first).to eq([:respond, { content: "secret", ephemeral: true }])
  end

  it "builds views" do
    view = context.view do |v|
      v.row do
        button :open, style: :primary, label: "Open"
      end
    end

    expect(view.to_a.first[:components].first[:custom_id]).to eq("dk1:tickets:open")
  end

  it "shows modals" do
    context.show_modal("Open", route: :create) do |m|
      m.text_input :title, label: "Title"
    end

    call = interaction.calls.first
    expect(call.first).to eq(:show_modal)
    expect(call.last[:custom_id]).to eq("dk1:tickets:create")
    expect(call.last[:components].first[:type]).to eq(18)
  end

  it "raises user errors" do
    expect { context.error!("Nope") }.to raise_error(CordKit::UserError, "Nope")
    expect { context.halt! }.to raise_error(CordKit::Halt)
  end
end

RSpec.describe CordKit::ComponentContext do
  let(:runtime) { fake_runtime }
  let(:plugin) { double(plugin_name: :tickets) }
  let(:custom_id) { CordKit::CustomId.build(plugin: :tickets, route: :open, data: { id: 5 }) }
  let(:event) { FakeEvent.new(custom_id: custom_id) }
  subject(:context) do
    described_class.new(runtime: runtime, event: event, plugin: plugin,
                        params: { parsed: CordKit::CustomId.parse(custom_id) })
  end

  it "exposes inline state" do
    expect(context.state).to eq("id" => 5)
  end

  it "updates the component message" do
    context.update("updated")
    expect(event.interaction.calls.first).to eq([:update_message, { content: "updated" }])
  end

  it "defers an update" do
    context.defer_update
    expect(event.interaction.calls.first).to eq([:defer_update, {}])
  end
end

RSpec.describe CordKit::AutocompleteContext do
  let(:runtime) { fake_runtime }
  let(:plugin) { double(plugin_name: :tickets) }
  let(:event) { FakeEvent.new(options: { "query" => "a" }) }
  subject(:context) do
    described_class.new(runtime: runtime, event: event, plugin: plugin)
  end

  before do
    allow(event).to receive(:focused).and_return("query")
    allow(event).to receive(:respond) { |choices:| event.interaction.calls << [:autocomplete, choices] }
  end

  it "responds with normalized choices" do
    context.choices(a: 1, b: 2)

    expect(event.interaction.calls.first).to eq([:autocomplete, [{ name: "a", value: 1 }, { name: "b", value: 2 }]])
  end

  it "exposes the query" do
    expect(context.query).to eq("a")
  end
end
