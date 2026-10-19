# frozen_string_literal: true

# Options, subcommands, groups, checks and autocomplete.
class Config < CordKit::Plugin
  SETTINGS = {
    "welcome" => "Welcome to the server!",
    "goodbye" => "See you soon!"
  }.freeze

  command :config, "Read and write bot settings" do
    subcommand :get, "Read a setting" do
      option :key, :string, "Setting name", required: true, autocomplete: true
      autocomplete :key do |ctx|
        ctx.choices(SETTINGS.keys.grep(/#{Regexp.escape(ctx.query.to_s)}/i))
      end
      run do |ctx|
        value = SETTINGS[ctx[:key]]
        ctx.respond(value ? "#{ctx[:key]} = #{value}" : "No such setting.", ephemeral: value.nil?)
      end
    end

    subcommand :list, "List settings" do
      run do |ctx|
        ctx.respond SETTINGS.keys.join(", ")
      end
    end

    subcommand_group :admin, "Administrative actions" do
      subcommand :show, "Show every setting" do
        require_permissions :manage_server
        guild_only
        run do |ctx|
          lines = SETTINGS.map { |key, value| "#{key} = #{value}" }
          ctx.respond lines.join("\n"), ephemeral: true
        end
      end
    end
  end
end
