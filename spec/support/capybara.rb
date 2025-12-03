# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    begin
      driven_by :selenium_chrome_headless
    rescue StandardError => e
      # If Chrome/Selenium setup fails, skip JS tests with a warning
      skip "Skipping JS test - Chrome/Selenium not properly configured: #{e.message}"
    end
  end
end

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
