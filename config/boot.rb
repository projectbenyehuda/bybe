ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# Load environment-specific dotenv files with override to prevent shell env pollution
require 'dotenv'
Dotenv.overload(
  ".env.#{ENV['RAILS_ENV'] || 'development'}.local",
  ".env.#{ENV['RAILS_ENV'] || 'development'}",
  '.env'
)
