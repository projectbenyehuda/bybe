FROM ruby:3.3.9-trixie AS base

RUN apt-get update -qq \
  && apt-get install -y yaz libmagickwand-7.q16-10 libmariadb3 libcap2 libvips42t64 libyaml-0-2 pandoc chromium \
  && apt-get clean && rm -rf /tmp/* /var/tmp/*

WORKDIR /app

COPY Gemfile* ./
COPY Rakefile ./

COPY bin ./bin
COPY app ./app
COPY lib ./lib
COPY config ./config
COPY config.ru ./
COPY db ./db
COPY js ./js
COPY vendor ./vendor

ENV RAILS_ENV=production \
    RACK_ENV=production

FROM base AS builder

RUN apt-get install -y libyaz-dev libmagickwand-7.q16-dev default-libmysqlclient-dev libpcap-dev libyaml-dev \
    libvips-dev

RUN bundle install --deployment --without test development --jobs "$(grep -c ^processor /proc/cpuinfo)" \
    && find vendor/bundle/ -path "*/cache/*" -name "*.gem"   -delete \
    && find vendor/bundle/ -path "*/gems/*"  -name "*.[c|o]" -delete

# Copying public static assets
COPY public ./public

# rake tasks requires SECRET_KEY_BASE to be set, but we don't need it to be valid at this stage
RUN SECRET_KEY_BASE=1 bundle exec rake assets:precompile

FROM base AS runtime

COPY --from=builder /app/bin                 ./bin
COPY --from=builder /app/vendor/bundle       ./vendor/bundle
COPY --from=builder /usr/local/bundle/config /usr/local/bundle/config
COPY --from=builder /app/public ./public

EXPOSE 3000

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]