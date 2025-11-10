# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = Rails.root.join('spec/fixtures/cassettes')
  config.ignore_localhost = true
  config.configure_rspec_metadata!
  config.hook_into :webmock
  %w(DEEPSEEK_API_KEY OPENAI_API_KEY).each do |placeholder|
    config.filter_sensitive_data(placeholder) { ENV.fetch(placeholder) }
  end
end
