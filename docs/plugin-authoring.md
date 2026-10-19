# Plugin authoring guide

This guide walks through writing a production-ready plugin.

## File layout

```text
bot.rb
plugins/
  ping.rb
  config.rb
  tickets.rb
```

Each plugin should live in its own file and define exactly one `CordKit::Plugin` subclass.

## Naming

Route and custom ID names must match `/\A[a-z0-9_-]{1,32}\z/`. Use short, stable names. Renaming a
route breaks existing messages, so treat routes like a public API.

Plugin names are derived from the class name by default:

```ruby
class AdminTools < CordKit::Plugin # plugin_name => :admin_tools
end
```

You can override them:

```ruby
class Admin < CordKit::Plugin
  plugin_name :admin
end
```

## Lifecycle

```ruby
class Tickets < CordKit::Plugin
  def on_load
    logger.info("Tickets loaded")
  end

  def on_ready
    # Called every time discordrb becomes ready, including reconnects.
  end

  def on_unload
    # Release resources here.
  end
end
```

`on_load` and `on_unload` are called by the runtime. `on_ready` is called for every `ready` event.

## Accessing shared services

Plugin instances expose:

- `bot` – the discordrb bot,
- `config` – the CordKit configuration,
- `logger` – discordrb's logger by default,
- `state_store` – the configured state store,
- `runtime` – the CordKit runtime.

Because blocks are evaluated in the plugin instance, these are available directly:

```ruby
command :status, "Shows status" do |ctx|
  ctx.respond "Store has #{state_store.size} entries"
end
```

## State

Prefer embedding small payloads in custom IDs. CordKit inlines JSON when it fits and falls back to
the state store for larger payloads.

```ruby
ctx.respond "Ticket" do |view|
  view.row do
    button :close, label: "Close ticket", style: :danger
  end
end
```

```ruby
button :close do |ctx|
  ticket_id = ctx.state[:ticket_id]
  ctx.update "Closed ticket ##{ticket_id}"
end
```

Use the state store directly for sessions, drafts and other data that must outlive a single message:

```ruby
state_store.write({ step: 1 }, ttl: 600)
```

## Testing plugins

Plugins are plain classes. You can build a runtime with a fake or real discordrb container and
assert on registered commands without connecting to Discord:

```ruby
runtime = CordKit::Runtime.new(fake_container, sync: false)
runtime.register_plugin MyPlugin

expect(runtime.command_registry.payloads).to include(hash_including(name: "ping"))
```

See `spec/runtime_spec.rb` and `spec/plugin_spec.rb` for complete examples.

## Good practices

- Keep handlers small and delegate business logic to service objects.
- Use `ctx.error!` for expected failures and `rescue_from` for domain errors.
- Use cooldowns for expensive operations.
- Prefer ephemeral responses for errors and personal data.
- Use `guild_only` for commands that assume a server context.
- Validate assumptions about `ctx.server`, `ctx.member` and `ctx.bot_member` before using them.
