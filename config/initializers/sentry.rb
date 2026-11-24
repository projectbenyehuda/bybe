# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger]
  config.dsn = ENV['SENTRY_DSN']
  config.traces_sample_rate = 0.05

  config.enabled_patches << :logger
  config.std_lib_logger_filter = proc do |_logger, _message, severity|
    [:error, :fatal].include?(severity)
  end
end
