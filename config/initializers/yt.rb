# frozen_string_literal: true

require 'deployment_helpers'

unless DeploymentHelpers.assets_compilation?
  Yt.configuration.api_key = ENV.fetch('GOOGLE_API_KEY')
end
