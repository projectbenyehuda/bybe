# frozen_string_literal: true

FactoryBot.define do
  factory :pending_notification do
    transient do
      mailer_class { 'Notifications' }
      mailer_method { 'tag_approved' }
      # Real mailer arguments (models included) -- serialized exactly as NotificationService does.
      args { [] }
    end

    recipient_email { 'user@example.com' }
    notification_type { "#{mailer_class}##{mailer_method}" }
    notification_data do
      {
        'mailer_class' => mailer_class,
        'mailer_method' => mailer_method,
        'args' => ActiveJob::Arguments.serialize(args)
      }
    end
    created_at { Time.current }
  end
end
