# frozen_string_literal: true

require 'deployment_helpers'

prefix = case Rails.env
         when 'production'
           ENV['is_staging'] == 'true' ? 'staging' : nil
         when 'test'
           'test'
         end

unless DeploymentHelpers.assets_compilation?
  Chewy.settings = {
    host: ENV.fetch('ELASTICSEARCH_HOST'),
    prefix: prefix
  }
end

# Use :bypass as the root strategy so that Sidekiq jobs which don't
# explicitly set a Chewy strategy (e.g. ActiveStorage::AnalyzeJob) silently
# skip Elasticsearch indexing instead of raising UndefinedUpdateStrategy.
# Jobs that DO need indexing (e.g. Lexicon::IngestFile) wrap their work in
# Chewy.strategy(:atomic) themselves, which overrides this root.
Chewy.root_strategy = :bypass
