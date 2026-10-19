# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `CordKit::Bot#load_plugins` / `CordKit::Runtime#load_plugins` to require a directory of plugin
  files and register the plugins they define.
- `CordKit::Bot` now reads the token from `DISCORD_TOKEN` or `DISCORD_BOT_TOKEN` when `token:` is
  omitted.
- Command descriptions are optional; CordKit derives one from the command name when it is missing.

## [0.1.0] - 2026-10-19

### Added

- `CordKit::Plugin` with a declarative DSL for commands, options, subcommands, checks,
  cooldowns, components, modals, autocomplete handlers and raw discordrb events.
- `CordKit::Bot` and `CordKit.attach` for new and existing discordrb bots.
- `CordKit::Runtime` with transactional plugin registration and unloading.
- `CordKit::Context`, `ComponentContext`, `ModalContext` and `AutocompleteContext` with a response
  state machine and helpers (`respond`, `defer`, `edit`, `update`, `show_modal`, `values`, `state`).
- `CordKit::View` and `CordKit::ModalBuilder` with route-aware custom IDs.
- `CordKit::CustomId` with inline JSON payloads and state-store fallback.
- `CordKit::StateStore` interface and a thread-safe `Memory` implementation.
- `CordKit::Checks` and `CordKit::Cooldown`.
- `CordKit::Synchronizer` with guild/global scopes and `:replace`/`:merge` modes.
- Auto-defer watchdog for slow interactions.
- Examples, guides and an RSpec suite.

[Unreleased]: https://github.com/maslukasz/CordKit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/maslukasz/CordKit/releases/tag/v0.1.0
