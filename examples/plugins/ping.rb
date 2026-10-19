# frozen_string_literal: true

# The smallest useful CordKit plugin.
class Ping < CordKit::Plugin
  command :ping, "Replies with pong" do |ctx|
    ctx.respond "Pong!"
  end

  command :echo, "Echoes your text" do
    option :text, :string, "Text to repeat", required: true
    run do |ctx|
      ctx.respond ctx[:text], ephemeral: true
    end
  end
end
