# Testing

CordKit is tested with RSpec. The suite does not connect to Discord. It uses small fakes for the
discordrb container and interaction objects.

## Running the suite

```sh
bundle exec rspec
bundle exec rubocop
bundle exec rake
```

## Writing a plugin test

Plugins are classes, so you can assert on their definitions without a runtime:

```ruby
plugin = Class.new(CordKit::Plugin) do
  plugin_name :example
  command :ping, "Ping" do |ctx|
    ctx.respond("pong")
  end
end

expect(plugin.commands.first.name).to eq("ping")
```

To test registration, use a fake container that implements the discordrb handler methods you need.
`spec/support/fakes.rb` contains reusable helpers:

```ruby
container = FakeContainer.new
runtime = CordKit::Runtime.new(container, sync: false)
runtime.register_plugin(MyPlugin)

expect(container.application_commands).to have_key("ping")
```

## Testing contexts

`FakeInteraction` records calls so you can assert on the response state machine:

```ruby
interaction = FakeInteraction.new
event = FakeEvent.new(interaction: interaction)
context = CordKit::Context.new(runtime: runtime, event: event, plugin: plugin, command: command)

context.respond("hello")

expect(interaction.calls).to eq([[:respond, { content: "hello" }]])
```

## Testing synchronization

`CordKit::Synchronizer` calls discordrb API methods. In specs, stub them with WebMock or RSpec:

```ruby
allow(Discordrb::API::Application).to receive(:bulk_overwrite_guild_commands)
```

## Coverage

SimpleCov is enabled in `spec/spec_helper.rb`. The coverage report is written to `coverage/` and is
not committed.

## Guidelines

- Prefer behaviour tests over implementation tests.
- Add a spec for every new public method and every validation rule.
- Keep fakes minimal and local to the suite.
- Never require a real Discord token.
