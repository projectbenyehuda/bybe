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
end

# Firefox driver (preferred for stability)
Capybara.register_driver :selenium_firefox_headless do |app|
  options = Selenium::WebDriver::Firefox::Options.new
  options.add_argument('--headless')

  driver = Capybara::Selenium::Driver.new(app, browser: :firefox, options: options)

  # Set window size after driver initialization (Firefox ignores --width/--height in headless mode)
  driver.browser.manage.window.resize_to(1400, 1400)

  driver
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

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.server = :puma, { Silent: true }
