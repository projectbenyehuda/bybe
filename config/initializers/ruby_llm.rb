# frozen_string_literal: true

RubyLLM.configure do |config|
  config.openai_api_key = config.openai_api_key = ENV['OPENAI_API_KEY']
  # config.default_model = "gpt-4.1-nano"

  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end
