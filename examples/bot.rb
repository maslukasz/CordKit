# frozen_string_literal: true

# CordKit example bot.
#
# Run with:
#   DISCORD_TOKEN=... GUILD_ID=... bundle exec ruby examples/bot.rb
#
# In development CordKit registers commands in GUILD_ID. In production
# (CORDKIT_ENV=production) it registers global commands.

require "cordkit"

require_relative "plugins/ping"
require_relative "plugins/config"
require_relative "plugins/tickets"
require_relative "plugins/events"

bot = CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  config.environment = (ENV["CORDKIT_ENV"] || "development").to_sym
  config.guild_ids = [ENV.fetch("GUILD_ID").to_i] if ENV["GUILD_ID"]
  config.sync_mode = :replace
  config.auto_defer_after = 1.5
end

bot.plugin Ping
bot.plugin Config
bot.plugin Tickets
bot.plugin Events

bot.run
