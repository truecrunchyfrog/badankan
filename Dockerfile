FROM ruby:3.3

ENV TZ="Europe/Stockholm"

RUN apt-get update && apt-get install -y \
  libmagickwand-dev

# ImageMagick blocks PDF files by default. This removes that configuration.
# https://stackoverflow.com/questions/52998331/imagemagick-security-policy-pdf-blocking-conversion
RUN sed -i '/disable ghostscript format types/,+6d' /etc/ImageMagick-6/policy.xml

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["./main.rb"]
