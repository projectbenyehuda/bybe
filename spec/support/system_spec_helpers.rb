# frozen_string_literal: true

# Shared helpers for system specs
module SystemSpecHelpers
  # Check if WebDriver is available before loading the suite
  def webdriver_available?
    return @webdriver_available if defined?(@webdriver_available)

    @webdriver_available = begin
      # Try to access the WebDriver to see if it's configured
      driver = Capybara.current_session.driver
      driver.browser if driver.respond_to?(:browser)
      true
    rescue StandardError
      false
    end
  end

  # Check if an executable is available in PATH (cross-platform)
  def executable_in_path?(cmd)
    path = ENV.fetch('PATH', '')
    return false if path.empty?

    exts = if Gem.win_platform?
             ENV.fetch('PATHEXT', '').split(File::PATH_SEPARATOR).presence || ['.EXE', '.BAT', '.CMD', '']
           else
             ['']
           end

    path.split(File::PATH_SEPARATOR).any? do |dir|
      exts.any? do |ext|
        candidate = File.join(dir, "#{cmd}#{ext}")
        File.executable?(candidate) && !File.directory?(candidate)
      end
    end
  rescue SystemCallError
    false
  end

  # Check if Firefox is available (cached at module level for performance)
  def firefox_available?
    return SystemSpecHelpers.firefox_cached if SystemSpecHelpers.firefox_cached_set?

    result = executable_in_path?('firefox') && executable_in_path?('geckodriver')
    SystemSpecHelpers.firefox_cached = result
    result
  end

  # Module-level cache for Firefox availability
  class << self
    attr_accessor :firefox_cached

    def firefox_cached_set?
      defined?(@firefox_cached)
    end
  end
end

RSpec.configure do |config|
  config.include SystemSpecHelpers, type: :system
end
