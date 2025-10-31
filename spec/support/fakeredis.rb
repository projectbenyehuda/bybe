# frozen_string_literal: true

require 'fakeredis/rspec'

RSpec.configure do |config|
  config.before(:suite) do
    # Use fakeredis for all Redis connections in tests
    # The URL below is mocked by fakeredis and doesn't connect to an actual Redis server
    redis_config = { url: 'redis://localhost:6379/0', driver: :ruby }
    
    Sidekiq.configure_client do |c|
      c.redis = redis_config
    end
    
    Sidekiq.configure_server do |c|
      c.redis = redis_config
    end
  end
end
