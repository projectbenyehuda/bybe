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

  # Collapses exact duplicates into [notification, occurrences] pairs, preserving order.
  #
  # Exact means same type *and* same payload. Grouping on the type alone would be lossy: two
  # different tags approved are both 'Notifications#tag_approved' but are two different things to
  # tell the recipient about. Only a repeat of the identical notification -- a moderator
  # batch-processing the same suggestion, a re-approval -- is noise worth folding away.
  def self.collapse(notifications)
    notifications.group_by { |n| [n.notification_type, n.notification_data] }
                 .map { |_payload, occurrences| [occurrences.first, occurrences.size] }
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
