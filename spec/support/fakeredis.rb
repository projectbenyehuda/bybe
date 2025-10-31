# frozen_string_literal: true

require 'fakeredis/rspec'

RSpec.configure do |config|
  config.before(:suite) do
    # Use fakeredis for all Redis connections in tests
    Sidekiq.configure_client do |c|
      c.redis = { url: 'redis://localhost:6379/0', driver: :ruby }
    end
  end
end
