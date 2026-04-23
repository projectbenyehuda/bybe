# frozen_string_literal: true

# Helper methods to use during deploy and app initialization
module DeploymentHelpers
  # Assets compilation rake task tries to load whole app, which causes problems with some gems (e.g. Chewy) that
  # require external services (e.g. ElasticSearch) to be available.
  # This method can be used to skip some initialization when we precompile assets.
  def self.assets_compilation?
    # Check if we're in assets group (set by rails assets:precompile)
    return true if ENV['RAILS_GROUPS'].to_s.include?('assets')

    # Fallback to checking rake tasks
    if defined?(Rake.application)
      Rake.application.top_level_tasks.any? do |task|
        task.to_s == 'assets:precompile' ||
          task.to_s.start_with?('assets:precompile')
      end
    end
  end
end
