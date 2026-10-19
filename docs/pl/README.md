# CordKit – szybki start po polsku

CordKit to cienka warstwa na bibliotece [discordrb](https://github.com/shardlab/discordrb).
Nie forkuje jej i nie nadpisuje – korzysta wyłącznie z publicznego API discordrb.

## Instalacja

```ruby
# Gemfile
gem "cordkit"
```

```sh
bundle install
```

## Najprostsza komenda

```ruby
# plugins/ping.rb
class Ping < CordKit::Plugin
  command :ping, "Odpowiada pongiem" do |ctx|
    ctx.respond "Pong!"
  end
end
```

## Bot

```ruby
# bot.rb
require "cordkit"
require_relative "plugins/ping"

bot = CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  config.guild_ids = [123456789012345678] # używane w trybie development
end

bot.plugin Ping
bot.run
```

## Konfiguracja

```ruby
CordKit::Bot.new(token: ENV.fetch("DISCORD_TOKEN")) do |config|
  config.environment = :production
  config.command_scope = :auto    # :guild w dev, :global w produkcji
  config.guild_ids = [123, 456]   # albo :all
  config.sync = :on_ready
  config.sync_mode = :replace     # albo :merge
  config.auto_defer_after = 1.5
  config.state_ttl = 900
  config.owner_ids = [123456789012345678]
end
```

## Opcje i podkomendy

```ruby
command :config, "Konfiguracja" do
  subcommand :get, "Odczyt" do
    option :key, :string, "Klucz", required: true
    run { |ctx| ctx.respond "Wartość: #{ctx[:key]}" }
  end

  subcommand_group :admin, "Administracja" do
    subcommand :set, "Zapis" do
      option :key, :string, "Klucz", required: true
      option :value, :string, "Wartość", required: true
      require_permissions :manage_server
      run { |ctx| ctx.respond "Zapisano." }
    end
  end
end
```

## Przyciski i modale

```ruby
button :open_ticket, label: "Nowy ticket", style: :primary do |ctx|
  ctx.show_modal("Nowy ticket", route: :ticket_create) do |m|
    m.text_input :title, label: "Tytuł", required: true
    m.text_input :body, label: "Opis", style: :paragraph, required: true
  end
end

modal :ticket_create do |ctx|
  ctx.respond "Ticket: #{ctx.value(:title)}"
end
```

## Błędy i cooldowny

```ruby
command :daily, "Nagroda dzienna" do
  cooldown 3600, per: :user, message: "Wróć jutro."
  run do |ctx|
    ctx.error! "Już odebrano." unless Reward.available?(ctx.user.id)
    ctx.respond "Odebrano nagrodę!"
  end
end
```

## Pełna dokumentacja

- [README (English)](../../README.md)
- [Architektura](../architecture.md)
- [Tworzenie pluginów](../plugin-authoring.md)
- [Synchronizacja komend](../synchronization.md)
- [Testowanie](../testing.md)
