Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, Rails.configuration.constants['google_oauth_client_id'], Rails.configuration.constants['google_oauth_client_secret']
  provider :developer if Rails.env == 'development'
end
#OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.allowed_request_methods = [:post]
