require 'mechanize'
require 'dotenv/load'
require 'pdf/reader'
require 'rmagick'
require 'uri'
require 'fileutils'

PDF_DIR_NAME = 'pdf-temp'
SLIDES_DIR_NAME = 'slides-temp'

FileUtils.mkdir_p PDF_DIR_NAME
FileUtils.mkdir_p SLIDES_DIR_NAME

def scrape_moodle_pdfs(login_url, username, password, course_url, filter_activity_by_name)
  puts 'begin moodle scrape'

  agent = Mechanize.new

  puts 'going to login page'
  page = agent.get login_url

  puts 'logging in'
  form = page.form_with :id => 'login'
  form.username = username
  form.password = password
  form.submit

  puts 'going to course page'
  page = agent.get course_url

  puts 'scraping activities'
  pdf_names = {}

  page.search('.activity-item').each do |activity|
    if activity.at_css('.activityicon').attribute('src').to_s.include? '/pdf' # yes, the type of file is based off of the icon :/
      name = activity.attribute('data-activityname').to_s
      if filter_activity_by_name.call(name)
        pdf_url = activity.at_css('a').attribute('href').to_s
        page = agent.get pdf_url
        pdf_names[name] = page.save(File.join(PDF_DIR_NAME, "#{name}.pdf"))
        puts "downloaded PDF '#{name}' to '#{pdf_names[name]}'"
      end
    end
  end

  pdf_names
end

def pdf_to_slides(pdf_name, slide_filter)
  puts "extracting slides from '#{pdf_name}'"
  slide_filenames_and_links = {}

  im = Magick::Image.read(pdf_name)
  puts "magick: pdf is #{im.length} pages long"
  PDF::Reader.open(pdf_name) do |pdf_reader|
    puts "pdf-reader: pdf is #{pdf_reader.page_count} pages long"
    pdf_reader.pages.each_with_index do |slide, i|
      if slide_filter.call(slide)
        puts "slide #{i} is included"
        slide_filename = File.join(SLIDES_DIR_NAME, "#{i}.jpg")
        puts "saving slide image from '#{pdf_name}' (#{i}) to '#{slide_filename}'"
        im[i].write(slide_filename)
        slide_filenames_and_links[slide_filename] = URI.extract(slide.text, ['http', 'https'])
      end
    end
  end

  slide_filenames_and_links
end
