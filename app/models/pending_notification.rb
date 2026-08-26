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

  # The stored mailer arguments, with GlobalID references resolved back into records.
  # Raises ActiveJob::DeserializationError when a referenced record no longer exists.
  def mailer_args
    @mailer_args ||= ActiveJob::Arguments.deserialize(notification_data['args'] || [])
  end

  # False when a referenced record has since been deleted, i.e. this notification can never be
  # rendered and should be dropped rather than left to fail on every digest run.
  def resolvable?
    mailer_args
    true
  rescue ActiveJob::DeserializationError => e
    Rails.logger.warn("Dropping unresolvable pending notification #{id} (#{notification_type}): #{e.message}")
    false
  end
end
