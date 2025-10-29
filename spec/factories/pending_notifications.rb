# frozen_string_literal: true

FactoryBot.define do
  factory :pending_notification do
    recipient_email { 'user@example.com' }
    notification_type { 'Notifications#tag_approved' }
    notification_data do
      {
        mailer_class: 'Notifications',
        mailer_method: 'tag_approved',
        args: []
      }
    end
    created_at { Time.current }
  end
end
