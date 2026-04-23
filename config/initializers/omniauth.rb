# frozen_string_literal: true

require 'deployment_helpers'

unless DeploymentHelpers.assets_compilation?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID'), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET')
    provider :developer if Rails.env == 'development'
  end
  #OmniAuth.config.allowed_request_methods = [:post, :get]
  OmniAuth.config.allowed_request_methods = [:post]
end
