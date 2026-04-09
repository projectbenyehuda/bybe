FROM ruby:3.3.9-trixie

RUN apt-get update -qq \
  && apt-get install -y yaz libyaz-dev libmagickwand-7.q16-dev default-libmysqlclient-dev libpcap-dev libyaml-dev \
    pandoc chromium \
    cmake \
  && apt-get clean && rm -rf /tmp/* /var/tmp/*

WORKDIR /app

COPY Gemfile* ./
COPY Rakefile ./
RUN bundle install --deployment --without test

COPY bin ./bin
COPY app ./app
COPY lib ./lib
COPY config ./config
COPY config.ru ./

RUN bundle exec rake assets:precompile

ENTRYPOINT ["./bin/bundle"]
CMD ["exec", "puma", "-C", "config/puma.rb", "config.ru"]