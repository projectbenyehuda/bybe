# frozen_string_literal: true

# Model to store notifications that need to be buffered for users with throttled email preferences
class PendingNotification < ApplicationRecord
  serialize :notification_data, coder: JSON

  validates :recipient_email, :notification_type, :notification_data, presence: true

  scope :for_recipient, ->(email) { where(recipient_email: email) }
  scope :older_than, ->(time) { where('created_at < ?', time) }

  # Return all pending notifications grouped by recipient email
  def self.grouped_by_recipient
    all.group_by(&:recipient_email)
  end
end
