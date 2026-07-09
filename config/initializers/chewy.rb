# frozen_string_literal: true

prefix = case Rails.env
         when 'production'
           ENV['is_staging'] == 'true' ? 'staging' : nil
         when 'test'
           'test'
         else
           nil
         end
Chewy.settings = {
  host: ENV.fetch('ELASTICSEARCH_HOST'),
  prefix: prefix,
  delete_all_enabled: Rails.env.test? # to use Chewy.massacre in tests
}
