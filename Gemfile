# frozen_string_literal: true

ruby '3.3.9' # update only when GitHub CI runners support a newer non-head version

source 'https://rubygems.org'

gem 'actionview'
gem 'concurrent-ruby'
gem 'rails', '8.0.2.1'
gem 'rails-i18n', '~> 8' # version should match major version of Rails
gem 'sass-rails', '~> 6.0.0'
gem 'sprockets', '~> 4.2.1'

gem 'damerau-levenshtein' # string distance
gem 'mysql2'
gem 'omniauth-google-oauth2'
gem 'omniauth-twitter'
gem 'rails-ujs'
gem 'rufus-scheduler' # scheduler

gem 'active_data' # for *Search classes in Chewy
gem 'chewy' # for ElasticSearch 7.x
gem 'image_processing'
gem 'jquery-slick-rails' # for carousel slider
gem 'property_sets', '>= 3.7.1' # for key/value properties per model; version 3.7.1 supports Ruby 3.0 per https://github.com/zendesk/property_sets/issues/85
gem 'rails-jquery-autocomplete', '>= 1.0.5' # for auto-completion
# gem "mini_magick", ">= 4.9.4" # now (Rails 6.1) required by image_processing
gem 'human_enum_name' # i18n for enums
gem 'marcel', '~> 1'
gem 'msgpack', '>= 1.7.0' # required by ActiveSupport:MessagePack
gem 'omniauth-rails_csrf_protection'
gem 'rack-cors', require: 'rack/cors'

gem 'aws-sdk-s3' # for Active Storage
gem 'diffy'

gem 'simple_form', '~> 5.3.0'

gem 'kt-paperclip'

gem 'jbuilder', '~> 2.0' # for JSON APIs
gem 'sqlite3' # for dictionary imports
# gem 'rollbar' # error reporting. Airbrake replacement.

gem 'activerecord-session_store'
gem 'jquery-rails'
gem 'jquery-ui-rails'

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

gem 'client_side_validations'

gem 'execjs'
gem 'htmlentities'
gem 'kaminari'
gem 'mini_racer'
gem 'nokogiri'

gem 'rmultimarkdown' # new wrapper over Fletcher Penney's MultiMarkDown 6 (MMD 6)
gem 'yt' # for polling YouTube for new videos

gem 'gared', '>= 0.1.2' # https://gitlab.com/abartov/gared # for scraping bibliographic data from Hebrew sources
gem 'hebrew', '>= 0.2.1' # https://github.com/abartov/hebrew
# gem 'goldiloader'
gem 'haml'
# gem 'zoom', '~>0.4.1', :git => 'https://github.com/bricestacey/ruby-zoom.git' # for Z39.50 queries to libraries
gem 'docx' # for pre-processing DOCX files to preserve stanzas
gem 'gepub' # for generating EPUBs
gem 'haml-rails'
gem 'pandoc-ruby' # for converting to DOCX
gem 'paper_trail' # for versioning entities
gem 'project-honeypot2', '>= 0.1.3' # for HTTP:BL service by Project Honeypot
gem 'responders' # for respond_to at controller level (in api_controller)
gem 'rmagick' # for generating cover images for EPUBs
gem 'uglifier'
# gem 'forty_facets' # for faceted search
gem 'better_sjr' # ease debugging of server-side JS responses
# gem 'histogram' # for histograms in date filter
gem 'bootstrap4-datetime-picker-rails' # for date picker in filters
gem 'hebruby' # for Hebrew date handling
gem 'momentjs-rails' # for date picker in filters

gem 'ahoy_matey' # for recording events
gem 'blazer' # for exploring Ahoy events

gem 'grape', '~> 2.4.0'
gem 'grape-entity', '~> 1.0.1'
gem 'grape-swagger', '~> 2.1.2'
gem 'grape-swagger-entity', '~> 0.6.2'

gem 'puma'
gem 'puma_worker_killer' # cycle workers when they bloat
gem 'rack-attack' # control misbehaving clients
gem 'rswag-api'
gem 'rswag-ui'

## these were used for some legacy HtmlDir VIAF lookup stuff. They have a huge RAM footprint (~160MB per process), so commented out until needed again.
# gem 'rdf' #, '~> 2.0.1'
# gem 'linkeddata' # for RDF etc.
# gem 'rdf-vocab' # for SKOS predefined vocab
# gem 'sparql-client'#, '~> 2.0.1'

group :production do
  gem 'dalli'
  gem 'newrelic_rpm' # performance monitoring
  gem 'puma-daemon', require: false
end

group :test do
  gem 'faker', '~> 2.19.0'
  gem 'rails-controller-testing', '~> 1.0.5'
  gem 'simplecov', require: false
  gem 'turn', '0.8.2', require: false
end

group :development do
  gem 'capistrano', '~> 3.11', require: false
  gem 'capistrano3-puma'
  gem 'capistrano-rails', '~> 1.4', require: false
  gem 'capistrano-rvm'
  gem 'derailed_benchmarks'
  gem 'listen'
  gem 'rvm1-capistrano3', require: false
  gem 'web-console'
  # gem 'bullet' # for suggestions to add/remove eager loading
  gem 'active_record_query_trace'
  gem 'bcrypt_pbkdf'
  gem 'debug'
  gem 'ed25519'
  gem 'haml_lint', '~> 0.57.0', require: false
  gem 'immigrant'
  gem 'pronto'
  gem 'pronto-brakeman', require: false
  gem 'pronto-haml', require: false
  gem 'pronto-rubocop', require: false
  gem 'rubocop', '1.79.1', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'ruby-lsp-rspec', require: false
  gem 'ruby-prof' # for profiling
  gem 'stackprof'
end

group :test, :development do
  gem 'brakeman'
  gem 'dotenv', '~> 3.1.2'
  gem 'factory_bot_rails', '~> 6.2.0'
  gem 'rspec-rails'
  gem 'spring', '4.2.1' # later version yields https://github.com/rails/spring/issues/734
  gem 'spring-commands-rspec'

  gem 'capybara' # for integration tests
  gem 'webdrivers' # For system tests with a browser driver like Chrome/Firefox
end

gem 'sidekiq', '~> 7.2'
