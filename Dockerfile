FROM ruby:3.3

ENV TZ="Europe/Stockholm"

RUN apt-get update && apt-get install -y \
  libmagickwand-dev

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

CMD ["./main.rb"]
