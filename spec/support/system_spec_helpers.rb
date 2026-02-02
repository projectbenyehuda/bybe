# frozen_string_literal: true

module SystemSpecHelpers
  # Check if WebDriver is available and configured for system specs with JavaScript
  def webdriver_available?
    return false unless defined?(Capybara::Selenium)

    session = nil

    begin
      driver = Capybara.current_driver
      return false if driver.nil?

      # Instantiate a session and perform a simple operation to ensure the driver works
      session = Capybara::Session.new(driver, Capybara.app)
      session.visit('about:blank')

      true
    rescue StandardError => e
      Rails.logger.warn("WebDriver check failed: #{e.class}: #{e.message}")
      false
    ensure
      # Best-effort cleanup so we don't leave stray browser instances running
      begin
        session.driver.quit if session && session.driver.respond_to?(:quit)
      rescue StandardError => cleanup_error
        Rails.logger.debug("WebDriver cleanup failed: #{cleanup_error.class}: #{cleanup_error.message}") if defined?(Rails)
      end
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
