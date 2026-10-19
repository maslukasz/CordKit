# CordKit

[![CI](https://github.com/maslukasz/CordKit/actions/workflows/ci.yml/badge.svg)](https://github.com/maslukasz/CordKit/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/cordkit.svg)](https://rubygems.org/gems/cordkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.txt)

CordKit is a thin, beginner-friendly layer on top of [discordrb](https://github.com/shardlab/discordrb).
It does not fork, wrap or replace discordrb. Instead it uses discordrb's public API for the gateway,
data models, REST calls, interaction responses, component builders and command registration.

You keep everything discordrb gives you, and add:

- a plugin system where each file owns its commands and interaction handlers,
- a small declarative DSL for commands, options, subcommands and autocomplete,
- route-aware buttons, select menus and modals,
- checks and cooldowns,
- a consistent error pipeline,
- a state store with an in-memory default,
- automatic command synchronization for development and production.

```ruby
# plugins/ping.rb
class Ping < CordKit::Plugin
  command :ping, "Replies with pong" do |ctx|
    ctx.respond "Pong!"
  end
end
```

```ruby
# bot.rb
require "cordkit"

bot = CordKit::Bot.new do |config|
  config.guild_ids = [123456789012345678] # used in development
end

bot.load_plugins("plugins") # requires plugins/**/*.rb and registers the plugins
bot.run
```

That is the whole happy path: one file for a command, one file for the bot. The token is read from
`DISCORD_TOKEN` (or `DISCORD_BOT_TOKEN`) automatically.

## Table of contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [Plugin DSL](#plugin-dsl)
  - [Commands](#commands)
  - [Options](#options)
  - [Subcommands and groups](#subcommands-and-groups)
  - [Autocomplete](#autocomplete)
  - [Context menus](#context-menus)
  - [Components](#components)
  - [Modals](#modals)
  - [Checks](#checks)
  - [Cooldowns](#cooldowns)
  - [Errors](#errors)
  - [Raw discordrb events](#raw-discordrb-events)
- [Sending responses](#sending-responses)
- [Configuration](#configuration)
- [Command synchronization](#command-synchronization)
- [State store](#state-store)
- [Using CordKit with an existing bot](#using-cordkit-with-an-existing-bot)
- [Architecture](#architecture)
- [Examples](#examples)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add the gem to your `Gemfile`:

```ruby
gem "cordkit"
```

Then run:

```sh
bundle install
```

CordKit requires Ruby 3.2 or newer and discordrb 3.8 or newer.

## Quick start

1. Create a Discord application and a bot user.
2. Enable the `bot` and `applications.commands` scopes when inviting the bot.
3. Store the token in the `DISCORD_TOKEN` environment variable.
4. Create a bot file:

```ruby
# frozen_string_literal: true

require "cordkit"

bot = CordKit::Bot.new do |config|
  # In development CordKit registers commands in these servers by default.
  # In production it registers global commands.
  config.guild_ids = [123456789012345678]
end

bot.load_plugins("plugins")
bot.run
```

`CordKit::Bot` reads the token from `DISCORD_TOKEN` (or `DISCORD_BOT_TOKEN`), so you never repeat it in
code. `load_plugins` requires every `*.rb` file under `plugins/` and registers the plugins it finds.

5. Add your first plugin as `plugins/ping.rb`:

```ruby
# frozen_string_literal: true

class Ping < CordKit::Plugin
  command :ping, "Replies with pong" do |ctx|
    ctx.respond "Pong!"
  end
end
```

6. Run the bot:

```ruby
bot.run
```

`load_plugins("plugins")` already required `plugins/ping.rb` and registered `Ping`. If you prefer to
be explicit, `require_relative "plugins/ping"` and `bot.plugin Ping` still work.

When the bot becomes ready, CordKit synchronizes the commands automatically.

## Plugin DSL

Every plugin subclasses `CordKit::Plugin`. Blocks are evaluated in the context of a plugin instance,
so they can use `bot`, `config`, `logger` and `state_store` directly.

### Commands

The short form is one line:

```ruby
command :ping, "Replies with pong" do |ctx|
  ctx.respond "Pong!"
end
```

The description is optional. When you omit it, CordKit generates a readable one (`:ping` becomes
"Ping command"), which is handy while prototyping:

```ruby
command :ping do |ctx|
  ctx.respond "Pong!"
end
```

The advanced form is a configuration block. If the block has no arguments it configures the command;
if it has an argument it is treated as the handler:

```ruby
command :echo, "Echoes text" do
  option :text, :string, "Text to repeat", required: true
  run do |ctx|
    ctx.respond ctx[:text]
  end
end
```

`run`, `handle` and `execute` are aliases. If you skip the description, CordKit derives one from the
command name; otherwise it must be between 1 and 100 characters.

### Options

CordKit supports typed Discord options:

```ruby
command :profile, "Shows profile information" do
  user :user, "The user to inspect", required: true
  boolean :private, "Hide the result"
  channel :channel, "Where to post", channel_types: %i[text voice]
  integer :limit, "How many items", min_value: 1, max_value: 25
  run do |ctx|
    ctx.respond "User: #{ctx[:user].username}"
  end
end
```

Available helpers: `string`, `integer`, `number`, `boolean`, `user`, `channel`, `role`, `mentionable`
and `attachment`. The generic form is `option :name, :type, "Description", **options`.

Values are normalized by CordKit:

- `user`, `role` and `mentionable` return discordrb objects from the resolved payload,
- `channel` returns a `Discordrb::Channel`,
- `attachment` returns a `Discordrb::Attachment`,
- numbers are converted to `Integer` or `Float`,
- everything else stays as received.

### Subcommands and groups

Subcommands group related actions under one command:

```ruby
command :config, "Bot configuration" do
  subcommand :get, "Read a setting" do
    option :key, :string, "Setting name", required: true
    run { |ctx| ctx.respond "Value: #{config_value(ctx[:key])}" }
  end

  subcommand :set, "Write a setting" do
    option :key, :string, "Setting name", required: true
    option :value, :string, "Setting value", required: true
    require_permissions :manage_server
    run { |ctx| ctx.respond "Saved." }
  end
end
```

Use `subcommand_group` when you want a second level, for example `/admin config reload`:

```ruby
command :admin, "Administrative actions" do
  subcommand_group :config, "Configuration" do
    subcommand :reload, "Reload configuration" do
      require_permissions :manage_server
      run { |ctx| ctx.respond "Reloaded." }
    end
  end
end
```

Discord does not allow mixing direct subcommands and subcommand groups at the same level, so CordKit
rejects that during validation.

### Autocomplete

```ruby
command :search, "Search the catalog" do
  option :query, :string, "Search query", autocomplete: true
  autocomplete :query do |ctx|
    ctx.choices(Catalog.search(ctx.query).first(25).map { |item| [item.name, item.id] })
  end
  run { |ctx| ctx.respond "You picked #{ctx[:query]}" }
end
```

Autocomplete blocks can return an array or a hash and call `ctx.choices`. If they do not respond,
CordKit sends an empty choice list so Discord does not keep spinning.

### Context menus

```ruby
user_command "Inspect user" do |ctx|
  ctx.respond "User: #{ctx.target.username}", ephemeral: true
end

message_command "Bookmark message" do |ctx|
  ctx.respond "Saved message #{ctx.target.id}"
end
```

`ctx.target` returns the user or message the command was invoked on.

### Components

Routes make component custom IDs readable and namespaced. A symbol is a route; a string or regexp
matches a raw `custom_id` from any source.

```ruby
component :confirm do |ctx|
  ctx.update "Confirmed!"
end

button :cancel do |ctx|
  ctx.update "Cancelled."
end

select :pick_role do |ctx|
  ctx.respond "Selected: #{ctx.values.join(', ')}"
end

modal :ticket_create do |ctx|
  ctx.respond "Title: #{ctx.value(:title)}"
end
```

Build a view with route-aware IDs:

```ruby
ctx.respond "Choose an action" do |view|
  view.row do
    button :confirm, style: :success, label: "Confirm"
    button :cancel, style: :danger, label: "Cancel"
  end
end
```

If you need to pass data to a component, use `payload:`:

```ruby
view = ctx.view(payload: { ticket_id: ticket.id }) do |v|
  v.row do
    button :close, style: :danger, label: "Close ticket"
  end
end
ctx.respond "Ticket ##{ticket.id}", view: view
```

Inside the handler the payload is available through `ctx.state`. If the payload is too large to
fit in a custom ID, CordKit stores it in the state store automatically and only the token is
embedded.

Raw custom IDs and regular expressions still work:

```ruby
button "legacy_button" do |ctx|
  ctx.respond "Legacy handler"
end

button(/^report:(\d+)$/) do |ctx, report_id|
  ctx.respond "Report #{report_id}"
end
```

### Modals

```ruby
button :open_ticket, style: :primary, label: "New ticket" do |ctx|
  ctx.show_modal("Create a ticket", route: :ticket_create) do |m|
    m.text_input :title, label: "Title", required: true
    m.text_input :body, label: "Description", style: :paragraph, required: true
  end
end

modal :ticket_create do |ctx|
  ctx.respond "Ticket created: #{ctx.value(:title)}"
end
```

Modal fields use routes the same way components do. `ctx.value(:title)` builds the same custom ID
used by the modal builder.

### Checks

Checks run before the handler. Return a truthy value or raise `CordKit::CheckFailed` through the DSL.

```ruby
command :ban, "Bans a member" do
  require_permissions :ban_members
  require_bot_permissions :ban_members
  guild_only
  run { |ctx| ctx.respond "Banned." }
end
```

Built-in checks include `guild_only`, `dm_only`, `require_permissions`, `require_bot_permissions`,
`require_roles`, `require_users`, `require_servers`, `allow_channels`, `owner_only`, `nsfw` and `check`.

```ruby
check :beta, message: "This command is in beta." do |ctx|
  ctx.user.id == 123456789012345678
end
```

Plugin-wide checks run for every command, component and modal handler in that plugin.

### Cooldowns

```ruby
command :daily, "Collect your daily reward" do
  cooldown 3600, per: :user, message: "Come back tomorrow."
  run { |ctx| ctx.respond "Reward collected!" }
end
```

Scopes are `:user`, `:guild` and `:global`. A plugin-wide cooldown can be declared with
`cooldown 5, per: :user`.

### Errors

```ruby
command :risky, "Might fail" do
  run do |ctx|
    raise "Unexpected failure" if rand < 0.5

    ctx.error! "That is not allowed."
  end
end
```

`ctx.error!` raises a friendly `CordKit::UserError` and sends an ephemeral message. Unexpected
errors are logged and answered with the configured `default_error_message`.

Per-plugin handlers:

```ruby
rescue_from ArgumentError do |ctx, error|
  ctx.respond "Bad argument: #{error.message}", ephemeral: true
end

before do |ctx|
  logger.debug("Handling #{ctx.command_name}")
end

after do |ctx|
  logger.debug("Handled #{ctx.command_name}")
end
```

A global hook can be configured with `config.on_error = ->(ctx, error) { ... }`.

### Raw discordrb events

CordKit does not hide discordrb. You can register any discordrb event:

```ruby
on :message, start_with: "!" do |event|
  event.respond "Commands use slash commands now."
end

on :server_create do |event|
  logger.info("Joined #{event.server.name}")
end
```

The handler receives the original discordrb event object.

### Loading plugins

Plugins are plain classes. Register them one by one with `bot.plugin`, or point `load_plugins` at a
directory and let CordKit require and register everything it finds:

```ruby
bot.plugin Ping
bot.plugin Tickets

bot.load_plugins("plugins")                      # plugins/**/*.rb
bot.load_plugins("app/commands", pattern: "*.rb")
```

`load_plugins` is idempotent: plugins that are already registered are left untouched, and plugins
defined by those files are registered once.

## Sending responses

`CordKit::Context` wraps the interaction and tracks response state so you do not have to think
about Discord's three second window.

| Method | Behaviour |
| --- | --- |
| `ctx.respond` | First response, or a follow-up after the first response. |
| `ctx.defer` | Acknowledges the interaction without content. |
| `ctx.edit` | Edits the original response. |
| `ctx.follow_up` | Always sends a follow-up message. |
| `ctx.update` | Updates the message that contains a component (button/select). |
| `ctx.defer_update` | Acknowledges a component interaction without changing the message. |
| `ctx.show_modal` | Responds with a modal. |
| `ctx.delete_response` | Deletes the original response. |

Pass discordrb options directly:

```ruby
ctx.respond "Hello", ephemeral: true
ctx.respond embeds: [embed]
ctx.respond "Pick" do |view|
  view.row { button :ok, label: "OK" }
end
```

CordKit also installs a watchdog. If a handler does not respond within `auto_defer_after` seconds
(default 1.5), the interaction is deferred and the handler can respond later. Set
`config.auto_defer_after = 0` to disable it, or `defer` in a command definition to always defer.

## Configuration

```ruby
bot = CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  config.environment = :production
  config.command_scope = :auto       # :auto, :guild or :global
  config.guild_ids = [123, 456]      # or :all
  config.sync = :on_ready            # true, false or :on_ready
  config.sync_mode = :replace        # :replace or :merge
  config.auto_defer_after = 1.5
  config.auto_defer_ephemeral = false
  config.default_error_message = "Something went wrong."
  config.unknown_interaction_message = "This interaction is no longer available."
  config.state_ttl = 900
  config.owner_ids = [123456789012345678]
  config.logger = Discordrb::LOGGER
end
```

You can also pass options as keywords to `CordKit::Bot.new`:

```ruby
CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN"), guild_ids: [123], sync: false)
```

`command_scope = :auto` resolves to `:guild` in development and `:global` in production. The
environment comes from `config.environment` or the `CORDKIT_ENV` environment variable.

## Command synchronization

CordKit registers commands with discordrb's `Discordrb::API::Application` module:

- `bulk_overwrite_global_commands` for global commands,
- `bulk_overwrite_guild_commands` for guild commands.

The default `:replace` mode makes CordKit the owner of the command list. If another library also
manages commands, use `:merge` mode so existing commands are preserved:

```ruby
config.sync_mode = :merge
```

You can synchronize manually too:

```ruby
bot.sync_commands!            # uses the configured scope
bot.sync_commands!(scope: :guild, guild_ids: [123])
bot.sync_commands!(scope: :global)
```

Only shard 0 synchronizes commands, so sharded bots do not race each other.

## State store

The default state store is in-memory and thread-safe. It is enough for a single process.

```ruby
key = state_store.write({ user_id: 1 }, ttl: 600)
state_store.read(key)
state_store.delete(key)
```

Implement `CordKit::StateStore` to use Redis or another shared backend:

```ruby
class RedisStateStore
  def write(value, ttl: nil, key: nil)
    # ...
  end

  def read(key)
    # ...
  end

  def delete(key)
    # ...
  end
end

config.state_store = RedisStateStore.new
```

## Using CordKit with an existing bot

CordKit does not require you to subclass `CordKit::Bot`. Attach a runtime to any discordrb bot:

```ruby
require "discordrb"
require "cordkit"

bot = Discordrb::Bot.new(token: ENV.fetch("DISCORD_TOKEN"))
runtime = CordKit.attach(bot, sync: false)

runtime.register_plugin MyPlugin
bot.run
```

## Architecture

CordKit is deliberately small. The main pieces are documented in [docs/architecture.md](docs/architecture.md):

- `CordKit::Plugin` collects commands and handlers at class definition time.
- `CordKit::Runtime` wires one discordrb handler per interaction type and routes events.
- `CordKit::Command` is a validated, serializable command definition.
- `CordKit::Router` maps custom IDs to component handlers.
- `CordKit::Context` owns response state and helpers.
- `CordKit::Synchronizer` talks to Discord through discordrb's public API.

Read more:

- [docs/architecture.md](docs/architecture.md)
- [docs/plugin-authoring.md](docs/plugin-authoring.md)
- [docs/synchronization.md](docs/synchronization.md)
- [docs/testing.md](docs/testing.md)

## Examples

The [`examples`](examples) directory contains a runnable bot:

- `examples/bot.rb` – bot setup and plugin loading,
- `examples/plugins/ping.rb` – the smallest possible command,
- `examples/plugins/config.rb` – options, subcommands and autocomplete,
- `examples/plugins/tickets.rb` – buttons, modals and state,
- `examples/plugins/events.rb` – raw discordrb events.

Run it with:

```sh
DISCORD_TOKEN=... GUILD_ID=... bundle exec ruby examples/bot.rb
```

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
bundle exec rake
```

Property and integration tests live in `spec/`. YARD documentation is generated with
`bundle exec yard doc`.

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md) first.

For security issues, see [SECURITY.md](SECURITY.md).

## License

CordKit is released under the [MIT License](LICENSE.txt).
