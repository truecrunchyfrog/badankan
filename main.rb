#!/usr/bin/env ruby

require 'discordrb'
require 'dotenv/load'
require 'rufus-scheduler'
require 'base64'
require_relative 'moodle_pdf_scraper'

scheduler = Rufus::Scheduler.new

bot = Discordrb::Bot.new token: ENV['token']
last_message = nil

def exercise_check(bot)
  puts '--- begin reupload moodle PDF exercises procedure ---'
  exercise_category = bot.channel(ENV['exercise_parent_category'])
  scrape_moodle_pdfs(
    ENV['moodle_login_url'],
    ENV['moodle_username'],
    Base64.decode64(ENV['moodle_password_base64']),
    ENV['moodle_course_url'],
    # Only allow activities whose names are not already a channel in the exercises category.
    -> activity_name { exercise_category.text_channels.none? { |c| c.topic.eql? activity_name } },
    ).each do |name, pdf_filename|
    slide_filenames_and_links = pdf_to_slides(pdf_filename, -> page { page.text.downcase.include? ENV['exercise_slide_keyword'] })
    puts "creating channel for PDF '#{name}'"
    new_chan = exercise_category.server.create_channel(name, parent: exercise_category, topic: name)
    slide_filenames_and_links.each do |slide_filename, links|
      puts "uploading slide file '#{slide_filename}' with #{links.length} links"
      new_chan.send_file(File.open(slide_filename, 'r'))
      new_chan.send_message(links.join("\n")) if links.any?
    end

    slide_filenames_and_links.each { |f, _| File.delete(f) }
    File.delete(pdf_filename)
  end
  puts '--- end reupload moodle PDF exercises procedure ---'
end

scheduler.cron ENV['exercise_check_crontab'] do
  puts 'exercise check triggered by crontab'
  exercise_check(bot)
end

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
  else
    e.respond(content: 'Unknown')
  end
end

bot.register_application_command(:exercisechecktrigger, 'Uppdatera övningarna manuellt.')

bot.application_command :exercisechecktrigger do |event|
  break unless event.user.id.to_s == ENV['admin']

  event.respond(content: 'uppdaterar övningar manuellt...', ephemeral: true)
  exercise_check(bot)
  event.respond(content: 'övningar uppdaterade!', ephemeral: true)
end

bot.run

scheduler.join