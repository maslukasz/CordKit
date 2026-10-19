# Architecture

CordKit is a library, not a framework replacement. It builds on discordrb's public API and keeps
the original objects visible to plugin authors. This document explains the moving parts and the
rules that keep the project maintainable.

## Design goals

1. **Use discordrb, do not fork it.** CordKit never copies discordrb internals and never patches
   discordrb classes. It relies on gateway events, data models, REST helpers and interaction
   responders exactly as documented by discordrb.
2. **Beginner-friendly defaults, advanced escape hatches.** A command is one line. Everything else
   is optional and discoverable.
3. **One handler per event type.** CordKit registers a single handler for buttons, selects, modals
   and autocomplete. Routing happens in-process, which makes unloading and testing straightforward.
4. **Open-source friendly process.** Public APIs are documented, specs cover behaviour, and the
   contribution and release workflows are explicit.

## Objects

### `CordKit::Plugin`

A plugin is a class. Class macros collect data at definition time:

- `commands` – list of top-level `CordKit::Command` objects,
- `component_definitions` – buttons, selects and modals,
- `autocomplete_definitions` – plugin-level autocomplete handlers,
- `event_definitions` – raw discordrb events,
- `checks`, `before_hooks`, `after_hooks`, `rescue_handlers`, `cooldown_setting`.

Instances exist to provide runtime helpers (`bot`, `config`, `logger`, `state_store`) and lifecycle
hooks (`on_load`, `on_ready`, `on_unload`). Blocks are evaluated with `instance_exec`, so plugin
instances can expose helpers without polluting the global namespace.

### `CordKit::Command`

A command is a validated, serializable definition. It can be:

- a chat input command,
- a user or message context menu command,
- a subcommand,
- a subcommand group.

Validation happens in `Command#validate!` and rejects invalid names, descriptions, option
combinations, missing handlers and unsupported nesting. Serialization to Discord's JSON shape
happens in `Command#to_h`, `#subcommand_payload` and `#group_payload`.

### `CordKit::CommandBuilder`

The DSL builder used by `CordKit::Plugin.command`. It supports the simple form (a block with an
argument) and the advanced form (a configuration block). It also provides check and cooldown
helpers.

### `CordKit::CommandRegistry`

Owns top-level commands and detects duplicate names across plugins. It exposes `payloads` for
synchronization.

### `CordKit::Router`

Maps component interactions to handlers. Two mechanisms coexist:

- **routes** – `CordKit::CustomId` builds `dk1:<plugin>:<route>` IDs. Routes are namespaced per
  plugin and can carry inline state or a state-store token.
- **raw matchers** – strings and regexps match custom IDs created by other libraries or older
  versions of your bot.

`Router#find_component` first tries the route table when the custom ID has the `dk1` prefix, then
falls back to raw exact and regexp matchers.

### `CordKit::Context`

Wraps an interaction event. Subclasses specialize behaviour:

- `ComponentContext` for buttons and selects (`update`, `defer_update`, `values`, `state`),
- `ModalContext` for modal submissions (`value`, `values`, `attachments`),
- `AutocompleteContext` for autocomplete (`query`, `choices`).

`Context` owns the response state machine. Discord interactions must be acknowledged quickly. The
context tracks whether the interaction was acknowledged, deferred and completed, and routes later
calls to `edit_response` or `send_message` appropriately.

### `CordKit::Runtime`

The integration point:

- creates global discordrb handlers,
- registers and unloads plugins,
- binds application command handlers, including subcommands and groups,
- runs checks, cooldowns, before/after hooks and error handlers,
- starts the auto-defer watchdog,
- synchronizes commands on `ready`.

Registration is transactional: if a plugin fails to register, its commands, routes and handlers are
rolled back.

### `CordKit::Synchronizer`

Calls `Discordrb::API::Application.bulk_overwrite_global_commands` and
`bulk_overwrite_guild_commands`. `:replace` mode owns the command list. `:merge` mode preserves
commands that CordKit does not manage.

## Interaction flow

1. discordrb receives a gateway event and raises it through `Bot#raise_event`.
2. One of CordKit's global handlers runs in discordrb's handler thread.
3. The runtime resolves the plugin handler.
4. Checks and cooldowns run.
5. A `CordKit::Context` is created and the handler executes.
6. The auto-defer watchdog acknowledges slow interactions.
7. Errors are routed through plugin `rescue_from` handlers, the global error hook, then the default
   error message.

## Concurrency

- discordrb raises each handler in a new thread. CordKit does not add another thread pool.
- The auto-defer watchdog uses one short-lived thread per interaction; it is killed when the handler
  finishes.
- `CordKit::StateStore::Memory` is protected by a mutex.
- Command synchronization uses a mutex and only runs on shard 0.

## Versioning

CordKit follows [Semantic Versioning](https://semver.org/). While the major version is `0`, minor
releases may include breaking changes, and the changelog calls them out under `Changed` or
`Removed`.

## Extension points

If you need to extend CordKit, prefer composition:

- wrap or decorate `CordKit::Context` and pass it from a plugin helper,
- implement `CordKit::StateStore` for shared state,
- register raw discordrb events for features CordKit does not model,
- use `CordKit::View` and `CordKit::ModalBuilder` directly when you need full control.

Open an issue before adding new global behaviour so it can be designed with the rest of the library.
