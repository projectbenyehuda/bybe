#!/bin/sh
set -e

bundle install
rake db:create RAILS_ENV=test
rake db:migrate RAILS_ENV=test

exec "$@"