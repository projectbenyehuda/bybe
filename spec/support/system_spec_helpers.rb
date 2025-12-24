# frozen_string_literal: true

# Shared helpers for system specs
module SystemSpecHelpers
  # Check if WebDriver is available before loading the suite
  def webdriver_available?
    return @webdriver_available if defined?(@webdriver_available)

    @webdriver_available = begin
      # Try to access the WebDriver to see if it's configured
      driver = Capybara.current_session.driver
      if driver.respond_to?(:browser)
        driver.browser
        true
      else
        true  # Non-Selenium driver, assume it works
      end
    rescue Selenium::WebDriver::Error::WebDriverError,
           Selenium::WebDriver::Error::UnknownError,
           Net::ReadTimeout,
           Errno::ECONNREFUSED,
           StandardError
      false
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
