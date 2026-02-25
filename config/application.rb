require_relative 'boot'

require 'rails/all'
require 'active_job'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Bybeconv
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # but use SHA1 for key generation, as in Rails 6.1, because there are links to storage objects embedded in markdown
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks capistrano templates))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    config.active_job.queue_adapter = :sidekiq
    config.active_job.queue_name_prefix = Rails.env

    config.i18n.default_locale = :he
    config.i18n.available_locales = %i(he en)
    config.i18n.enforce_available_locales = true
    config.i18n.fallbacks = %i(he)

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i(get post put patch delete options)
      end
    end
    # BYBE's own configuration
    config.constants = config_for(:constants)
    if ENV['PROFILE'] == 'true'
      config.middleware.use Rack::RubyProf, path: './tmp/profile'
    end
  end
end
