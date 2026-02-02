# frozen_string_literal: true

module SystemSpecHelpers
  # Check if WebDriver is available and configured for system specs with JavaScript
  def webdriver_available?
    return false unless defined?(Capybara::Selenium)

    begin
      # Try to get the current driver
      Capybara.current_driver
      true
    rescue StandardError => e
      Rails.logger.warn("WebDriver check failed: #{e.message}")
      false
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
