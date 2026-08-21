# frozen_string_literal: true

require 'deployment_helpers'

unless DeploymentHelpers.assets_compilation?
  Paperclip::Attachment.default_options[:storage] = :s3
  Paperclip::Attachment.default_options[:s3_credentials] = {
    access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
    secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
    bucket: ENV.fetch('S3_BUCKET'),
    s3_region: ENV.fetch('S3_REGION'),
  }
end
