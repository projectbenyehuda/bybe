# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    # Try Firefox first, fall back to Chrome if not available
    driver = if firefox_available?
               :selenium_firefox_headless
             else
               :selenium_chrome_headless
             end
    driven_by driver
  rescue StandardError => e
    # If both browsers fail, skip JS tests with a warning
    skip "Skipping JS test - Browser/Selenium not properly configured: #{e.message}"
  end

  # Helper to check if Firefox is available
  def firefox_available?
    return @firefox_available if defined?(@firefox_available)

    @firefox_available = begin
      # Check if firefox/geckodriver is in PATH
      system('which firefox > /dev/null 2>&1') && system('which geckodriver > /dev/null 2>&1')
    rescue StandardError
      false
    end
  end
end

# Firefox driver (preferred for stability)
Capybara.register_driver :selenium_firefox_headless do |app|
  options = Selenium::WebDriver::Firefox::Options.new
  options.add_argument('--headless')
  options.add_argument('--width=1400')
  options.add_argument('--height=1400')

  begin
    Capybara::Selenium::Driver.new(app, browser: :firefox, options: options)
  rescue Webdrivers::NetworkError, Selenium::WebDriver::Error::WebDriverError => e
    Rails.logger.warn "Firefox/Selenium driver setup failed: #{e.message}. Falling back to Chrome."
    nil
  end
end

# Chrome driver (fallback)
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')
  options.add_argument('--disable-search-engine-choice-screen')

  # Use Chrome for Testing to avoid chromedriver version issues
  begin
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  rescue Webdrivers::NetworkError, Selenium::WebDriver::Error::WebDriverError => e
    # Fallback: try without webdrivers gem managing the driver
    Rails.logger.warn "Chrome/Selenium driver setup failed: #{e.message}. Tests requiring JavaScript will be skipped."
    nil
  end
end

Capybara.server = :puma, { Silent: true }
