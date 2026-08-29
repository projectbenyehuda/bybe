# frozen_string_literal: true

module SystemSpecHelpers
  # Resize the browser window. Note that the :narrow_viewport tag only picks the Chrome driver
  # (headless Firefox will not go below 500px wide) -- it does NOT resize anything, and the
  # before hook in spec/support/capybara.rb sizes every `:js, type: :system` spec to 1400x900.
  # A spec asserting mobile layout therefore has to call this itself.
  def resize_window(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  # Wait until the page has scrolled away from the top, and return the resulting offset.
  # Capybara's matchers cannot express a scroll position, so we drive its own polling loop
  # rather than sleeping for an animation to finish.
  def wait_until_scrolled(wait: Capybara.default_max_wait_time)
    page.document.synchronize(wait, errors: [Capybara::ExpectationNotMet]) do
      offset = page.evaluate_script('window.pageYOffset || document.documentElement.scrollTop').to_f
      raise Capybara::ExpectationNotMet, "page is still at the top (offset #{offset})" unless offset > 0

      offset
    end
  end

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
