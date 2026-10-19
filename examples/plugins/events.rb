# frozen_string_literal: true

# Raw discordrb events are still available.
class Events < CordKit::Plugin
  on :server_create do |event|
    logger.info("Joined server #{event.server.name}")
  end

  on :member_join do |event|
    logger.info("#{event.user.name} joined")
  end

  on :message, start_with: "!" do |event|
    event.respond "CordKit uses slash commands now."
  end

  before do |ctx|
    logger.debug("#{plugin_name}: handling #{ctx.command_name}")
  end

  after do |ctx|
    logger.debug("#{plugin_name}: handled #{ctx.command_name}")
  end

  rescue_from ArgumentError do |ctx, error|
    ctx.respond "Bad argument: #{error.message}", ephemeral: true
  end
end
