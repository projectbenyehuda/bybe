# frozen_string_literal: true

# ActiveJob to send digest emails for users with daily/weekly email frequency preferences
class NotificationDigestJob < ApplicationJob
  def perform(frequency)
    # Validate frequency parameter
    unless %w(daily weekly).include?(frequency)
      Rails.logger.error("Invalid frequency: #{frequency}")
      return
    end

    # Get all users with this email frequency preference
    preferences_join = 'INNER JOIN base_user_preferences ' \
                       'ON base_user_preferences.base_user_id = base_users.id'
    users_with_frequency = BaseUser.joins(:user)
                                   .joins(preferences_join)
                                   .where("base_user_preferences.name = 'email_frequency' " \
                                          'AND base_user_preferences.value = ?', frequency)

    users_with_frequency.find_each do |base_user|
      email = base_user.user&.email
      next if email.blank?

      send_digest_for_user(email)
    end
  end

  private

  # Drains everything currently buffered for the recipient, regardless of age: the once-per-period
  # guarantee comes from the schedule in config/recurring.yml, not from an age filter. Filtering by
  # age here only bought a full extra period of delivery latency.
  def send_digest_for_user(email)
    pending = PendingNotification.for_recipient(email).to_a

    return if pending.empty?

    renderable, unresolvable = pending.partition(&:resolvable?)

    # A notification referring to a since-deleted record can never render. Drop it, so that it does
    # not fail again on every subsequent run and block this recipient's other notifications.
    delete_notifications(unresolvable)

    return if renderable.empty?

    # Send digest email
    Notifications.notification_digest(email, renderable).deliver_now

    # Delete the notifications after sending
    delete_notifications(renderable)
  rescue StandardError => e
    Rails.logger.error("Failed to send digest for #{email}: #{e.message}")
  end

  def delete_notifications(notifications)
    return if notifications.empty?

    PendingNotification.where(id: notifications.map(&:id)).delete_all
  end
end
