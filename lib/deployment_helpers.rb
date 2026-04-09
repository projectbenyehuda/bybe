# frozen_string_literal: true

module DeploymentHelpers
  # Assets compilation rake task tries to load whole app, which causes problems with some gems (e.g. Chewy) that
  # require external services (e.g. ElasticSearch) to be available.
  # This method can be used to skip some initialization when we precompile assets.
  def self.assets_compilation?
    defined?(::Rake::SprocketsTask)
  end
end