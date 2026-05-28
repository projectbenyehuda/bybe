# frozen_string_literal: true

if Rails.env.production?
  ActionMailer::Base.smtp_settings = {
    address: 'smtp-relay.gmail.com',
    domain: ENV.fetch('APP_HOSTNAME', 'benyehuda.org')
  }
end
