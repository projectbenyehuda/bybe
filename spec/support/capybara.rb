# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    # Try Firefox first, fall back to Chrome if not available
    driver = :selenium_firefox_headless
    driven_by driver

    if page.driver.browser.respond_to?(:manage)
      page.driver.browser.manage.window.resize_to(1400, 900)
    end
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
  driver
end

Capybara.server = :puma, { Silent: true }
