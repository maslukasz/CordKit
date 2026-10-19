# frozen_string_literal: true

# Buttons, selects, modals and state.
class Tickets < CordKit::Plugin
  # In-memory ticket storage for the example.
  TICKETS = {} # rubocop:disable Style/MutableConstant

  command :ticket, "Open the ticket panel" do |ctx|
    ctx.respond "Need help? Open a ticket." do |view|
      view.row do
        button :open_ticket, style: :primary, label: "Open ticket"
      end
    end
  end

  button :open_ticket do |ctx|
    ctx.show_modal("Create a ticket", route: :ticket_create) do |modal|
      modal.text_input :title, label: "Title", required: true
      modal.text_input :body, label: "Describe the issue", style: :paragraph, required: true
    end
  end

  modal :ticket_create do |ctx|
    id = TICKETS.size + 1
    TICKETS[id] = { title: ctx.value(:title), body: ctx.value(:body), user: ctx.user.id }
    ctx.respond "Ticket ##{id} created.", ephemeral: true
  end

  command :tickets, "List your tickets" do |ctx|
    mine = TICKETS.select { |_id, ticket| ticket[:user] == ctx.user.id }
    if mine.empty?
      ctx.respond "You have no tickets.", ephemeral: true
    else
      lines = mine.map { |id, ticket| "##{id}: #{ticket[:title]}" }
      ctx.respond lines.join("\n"), ephemeral: true
    end
  end

  # Route with payload/data.
  command :announce, "Announcement with buttons" do
    option :text, :string, "Announcement text", required: true
    run do |ctx|
      view = ctx.view(payload: { text: ctx[:text] }) do |v|
        v.row do
          button :confirm_read, style: :success, label: "Got it"
        end
      end
      ctx.respond ctx[:text], view: view
    end
  end

  button :confirm_read do |ctx|
    ctx.update "#{ctx.state[:text]} (read by #{ctx.user.name})"
  end
end
