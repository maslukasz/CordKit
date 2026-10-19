# Synchronization

CordKit registers application commands through discordrb's public API:

- `Discordrb::API::Application.bulk_overwrite_global_commands`
- `Discordrb::API::Application.bulk_overwrite_guild_commands`

## Scopes

| Scope | When to use | Endpoint |
| --- | --- | --- |
| `:guild` | Development, staging, private servers | Guild commands |
| `:global` | Production | Global commands |

`command_scope = :auto` resolves to `:guild` in development and `:global` in production.

```ruby
config.environment = :development
config.command_scope = :auto
config.guild_ids = [123456789012345678]
```

In production, set `environment = :production` (or `CORDKIT_ENV=production`) and CordKit registers
globally. Global commands can take up to an hour to propagate, which is why development defaults to
guild commands.

## Modes

### `:replace`

CordKit owns the command list. Any command it does not define is removed.

```ruby
config.sync_mode = :replace
```

### `:merge`

CordKit preserves commands created by other tools and replaces only the commands it manages.
Use this when migrating from another command library or when another library also registers commands.

```ruby
config.sync_mode = :merge
```

Merge mode performs a read-modify-write with `get_global_commands` or `get_guild_commands` before
overwriting. If two processes synchronize at the same time, the last writer wins.

## Timing

Synchronization starts when discordrb emits `ready`. Only shard 0 synchronizes, so sharded bots do
not fight each other.

Configure it with:

```ruby
config.sync = :on_ready # default
config.sync = true     # same as :on_ready
config.sync = false    # disable automatic synchronization
```

Manual synchronization:

```ruby
bot.sync_commands!
bot.sync_commands!(scope: :guild, guild_ids: [123])
bot.sync_commands!(scope: :global)
```

## Failure handling

Synchronization failures are logged. The runtime keeps `synced?` false and will try again on the next
`ready` event. You can also catch errors from a manual call.

Common causes:

- missing `applications.commands` scope on the invite,
- invalid command payload (validation should catch most issues during plugin registration),
- rate limits – discordrb and Discord handle these, but very large command sets may take a moment,
- guild commands in a server the bot has not joined.
