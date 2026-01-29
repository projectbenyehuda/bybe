# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do
    driven_by :selenium_firefox_headless
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end

# Firefox driver (preferred for stability)
Capybara.register_driver :selenium_firefox_headless do |app|
  options = Selenium::WebDriver::Firefox::Options.new
  options.add_argument('--headless')
  options.add_argument('--width=1400')
  options.add_argument('--height=900')
  Capybara::Selenium::Driver.new(app, browser: :firefox, options: options)
end

Capybara.server = :puma, { Silent: true }
