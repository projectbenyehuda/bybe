FROM ruby:3.3.9-trixie AS base

RUN apt-get update -qq \
  && apt-get install -y yaz libmariadb3 libcap2 libvips42t64 libyaml-0-2 chromium libjemalloc2 \
    libopengl0 libxcb-cursor0 \
  && wget https://github.com/jgm/pandoc/releases/download/3.8.3/pandoc-3.8.3-1-amd64.deb -O /tmp/pandoc.deb \
  && dpkg -i /tmp/pandoc.deb \
  && apt-get clean \
  && wget -nv https://download.calibre-ebook.com/linux-installer.sh -O /tmp/calibre-installer.sh \
  && sh /tmp/calibre-installer.sh version=9.14.0 \
  && rm -rf /tmp/* /var/tmp/*

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

RUN apt-get install -y libyaz-dev default-libmysqlclient-dev libpcap-dev libyaml-dev libvips-dev

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

# Stamp the deployed commit into the image, for the version indicator (ApplicationHelper#deployment_sha).
# These change on every commit, so they must stay in the LAST layers of the stage: anything below an
# ARG/ENV is cache-busted on every build, and the expensive layers above must keep their cache.
ARG GIT_SHA=
ARG GIT_COMMITTED_AT=
ENV GIT_SHA=$GIT_SHA \
    GIT_COMMITTED_AT=$GIT_COMMITTED_AT

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2

EXPOSE 3000

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]