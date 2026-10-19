# frozen_string_literal: true

require_relative "lib/cordkit/version"

Gem::Specification.new do |spec|
  spec.name          = "cordkit"
  spec.version       = CordKit::VERSION
  spec.authors       = ["maslukasz"]
  spec.email         = ["adres@example.com"]

  spec.summary       = "Beginner-friendly commands, plugins, and interactions for discordrb"
  spec.description   = <<~DESCRIPTION
    CordKit is a thin layer on top of discordrb. It adds a pleasant plugin system,
    declarative slash commands, component and modal routing, checks, cooldowns,
    autocomplete, state handling, and command synchronization without reimplementing
    the Discord API, gateway, or discordrb data models.
  DESCRIPTION

  spec.homepage      = "https://github.com/maslukasz/CordKit"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir[
    "lib/**/*.rb",
    "examples/**/*.rb",
    "docs/**/*.md",
    "README.md",
    "CHANGELOG.md",
    "LICENSE.txt"
  ]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.add_dependency "discordrb", "~> 3.8"
end
