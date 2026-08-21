# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, :js, type: :system) do |example|
    # Headless Firefox refuses to size its window below 500px wide, so specs that assert
    # layout at real phone widths (320/360/390px) have to run under Chrome.
    driven_by example.metadata[:narrow_viewport] ? :selenium_chrome_headless : :selenium_firefox_headless
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

# Chrome driver, used only by specs tagged :narrow_viewport (see above)
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,900')
  options.add_argument('--disable-search-engine-choice-screen')
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.server = :puma, { Silent: true }
