require 'discordrb'
require 'dotenv/load'
require 'rufus-scheduler'

scheduler = Rufus::Scheduler.new

bot = Discordrb::Bot.new token: ENV['token']
last_message = nil

scheduler.cron ENV['presence_crontab'] do
  unless last_message == nil
    last_message.delete
  end

  presence_link = ENV['presence_link']
  presence_link_channel = bot.channel(ENV['presence_link_channel'])
  presence_alert_role = ENV['presence_alert_role']

  last_message = presence_link_channel.send_embed("<@&#{presence_alert_role}>") do |embed, view|
      embed.title = 'Närvaro'
      embed.description =
        "Dags att registrera skoldagens närvaro! Gäller för dig som deltar på plats och/eller på distans.\n\n" \
        'Vill du bli pingad (meddelad) när det här meddelandet skickas ut? Ställ in det under *Hantera ping*.'
      embed.color = 0x814b84

      view.row do |r|
        r.button(label: 'Anmäl närvaro', style: :link, emoji: '✔', url: presence_link)
      end
      view.row do |r|
        r.select_menu(custom_id: 'role_select', placeholder: 'Hantera ping', max_values: 1) do |s|
          s.option(label: 'Snälla pinga', value: 'enable_ping', emoji: '🔔')
          s.option(label: 'Tystnad!', value: 'disable_ping', emoji: '🤫')
        end
      end
  end
end

bot.select_menu(custom_id: 'role_select') do |e|
  presence_alert_role = ENV['presence_alert_role']

  case e.values[0]
  when 'enable_ping'
    if e.user.role?(presence_alert_role)
      e.respond(content: 'Du har ju redan aktiverat ping!', ephemeral: true)
    else
      e.user.add_role(presence_alert_role)
      e.respond(content: '✔ Du kommer numera bli pingad med den här länken i framtiden.', ephemeral: true)
    end
  when 'disable_ping'
    if !e.user.role?(presence_alert_role)
      e.respond(content: 'Du har ju inte aktiverat ping än!', ephemeral: true)
    else
      e.user.remove_role(presence_alert_role)
      e.respond(content: '🔕 Du kommer inte längre bli pingad med den här länken i framtiden.', ephemeral: true)
    end
  end
end

bot.run

scheduler.join