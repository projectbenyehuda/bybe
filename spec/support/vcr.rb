# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec/fixtures/cassettes')
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.hook_into :webmock

  # The config below ensures we do not accidentally commit sensitive data like API keys in VCR cassettes.
  # Ensure all ENV variables that contain sensitive data are added to the array below.
  %w(OPENAI_API_KEY).each do |placeholder|
    config.filter_sensitive_data(placeholder) { ENV.fetch(placeholder) }
  end
end
