# frozen_string_literal: true

# CordKit example bot.
#
# Run with:
#   DISCORD_TOKEN=... GUILD_ID=... bundle exec ruby examples/bot.rb
#
# In development CordKit registers commands in GUILD_ID. In production
# (CORDKIT_ENV=production) it registers global commands.

require "cordkit"

bot = CordKit::Bot.new do |config|
  config.environment = (ENV["CORDKIT_ENV"] || "development").to_sym
  config.guild_ids = [ENV.fetch("GUILD_ID").to_i] if ENV["GUILD_ID"]
  config.sync_mode = :replace
  config.auto_defer_after = 1.5
end

# Requires every file in examples/plugins and registers the plugins it defines.
bot.load_plugins(File.expand_path("plugins", __dir__))

bot.run
