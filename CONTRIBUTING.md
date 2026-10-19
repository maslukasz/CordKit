# Contributing to CordKit

Thanks for taking the time to contribute. This document explains how to set up the project, what
we expect from changes and how releases are made.

## Code of Conduct

By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting started

```sh
git clone https://github.com/maslukasz/CordKit.git
cd cordkit
bundle install
bundle exec rspec
bundle exec rubocop
```

## What makes a good change

- A clear problem statement or use case in the pull request description.
- Tests for new behaviour and bug fixes.
- Documentation updates in `README.md` or `docs/` for user-facing changes.
- A changelog entry under `## [Unreleased]`.
- Public APIs documented with YARD comments.
- No dependency on discordrb internals. Use the public API only.

## Branching and commits

- Create a topic branch from `main`.
- Keep commits focused and describe the behaviour change.
- Reference issues in the pull request description, not in commit messages.

## Style

CordKit uses RuboCop with the configuration in `.rubocop.yml`. Run:

```sh
bundle exec rubocop -a
```

Prefer small methods, explicit names and `@return`/`@param` YARD tags on public methods.

## Tests

```sh
bundle exec rspec
bundle exec rspec spec/custom_id_spec.rb
```

Tests must not require a Discord token or network access. Use the fakes in `spec/support`.

## Documentation

- Update the README for user-facing features.
- Add or update guides in `docs/`.
- Keep `docs/pl/README.md` brief and link to the English docs for details.
- Generate YARD with `bundle exec yard doc` when changing public APIs.

## Pull requests

Please make sure:

1. CI passes.
2. New public methods have docs and specs.
3. The changelog is updated.
4. The PR is scoped to one logical change.

Maintainers may ask for changes before merging. Small, focused pull requests are reviewed fastest.

## Releases

Only maintainers publish releases.

1. Update `CordKit::VERSION` in `lib/cordkit/version.rb`.
2. Move `Unreleased` entries in `CHANGELOG.md` into the new version and add a date.
3. Commit, tag `vX.Y.Z` and push the tag.
4. The release workflow builds and pushes the gem.

The project follows [Semantic Versioning](https://semver.org/). While the major version is `0`,
minor versions may contain breaking changes; the changelog calls them out.

## Security

Do not open public issues for security problems. See [SECURITY.md](SECURITY.md).
