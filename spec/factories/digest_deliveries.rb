# frozen_string_literal: true

FactoryBot.define do
  factory :digest_delivery do
    recipient_email { 'user@example.com' }
    last_digest_sent_at { Time.current }
  end
end
