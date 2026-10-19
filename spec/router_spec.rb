# frozen_string_literal: true

RSpec.describe CordKit::Router do
  subject(:router) { described_class.new(fake_runtime) }

  let(:plugin) { double(plugin_name: :tickets) }

  def definition(type:, matcher:, route: nil, &block)
    CordKit::Plugin::ComponentDefinition.new(type: type, matcher: matcher, route: route, block: block || proc {})
  end

  it "registers and finds route handlers" do
    router.register_component(plugin, definition(type: :button, matcher: :open, route: "open"))
    custom_id = CordKit::CustomId.build(plugin: :tickets, route: :open)

    handler, captures, parsed = router.find_component(:button, custom_id)
    expect(handler.plugin.plugin_name).to eq(:tickets)
    expect(captures).to eq([])
    expect(parsed.route).to eq("open")
  end

  it "matches a generic select handler from a specific select event" do
    router.register_component(plugin, definition(type: :select, matcher: :menu, route: "menu"))
    custom_id = CordKit::CustomId.build(plugin: :tickets, route: :menu)

    expect(router.find_component(:string_select, custom_id)).not_to be_nil
  end

  it "matches raw string and regexp custom IDs" do
    router.register_component(plugin, definition(type: :button, matcher: "legacy"))
    router.register_component(plugin, definition(type: :button, matcher: /^prefix:(\d+)$/))

    expect(router.find_component(:button, "legacy")).not_to be_nil
    _handler, captures, = router.find_component(:button, "prefix:42")
    expect(captures).to eq(["42"])
  end

  it "rejects duplicate routes" do
    router.register_component(plugin, definition(type: :button, matcher: :open, route: "open"))
    expect do
      router.register_component(plugin, definition(type: :button, matcher: :open, route: "open"))
    end.to raise_error(CordKit::RouteError)
  end

  it "removes plugin handlers" do
    router.register_component(plugin, definition(type: :button, matcher: :open, route: "open"))
    router.remove_plugin(:tickets)

    expect(router.find_component(:button, CordKit::CustomId.build(plugin: :tickets, route: :open))).to be_nil
  end

  it "finds autocomplete handlers" do
    autocomplete = CordKit::Plugin::AutocompleteDefinition.new(
      command_name: :demo, option_name: :query, group: nil, subcommand: nil, block: proc {}
    )
    router.register_autocomplete(plugin, autocomplete)

    expect(router.find_autocomplete(:demo, nil, nil, :query)).not_to be_nil
  end
end
