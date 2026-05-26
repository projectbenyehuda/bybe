# frozen_string_literal: true

if Rails.env.production? && !DeploymentHelpers.assets_compilation?
  ActionMailer::Base.smtp_settings = {
    address: 'smtp-relay.gmail.com',
    domain: SiteConstants::APP_HOSTNAME
  }
end
