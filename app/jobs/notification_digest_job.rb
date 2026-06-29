# frozen_string_literal: true

# ActiveJob to send digest emails for users with daily/weekly email frequency preferences
class NotificationDigestJob < ApplicationJob
  def perform(frequency)
    # Validate frequency parameter
    unless %w(daily weekly).include?(frequency)
      Rails.logger.error("Invalid frequency: #{frequency}")
      return
    end

    # Calculate the cutoff time based on frequency
    cutoff_time = case frequency
                  when 'daily'
                    1.day.ago
                  when 'weekly'
                    1.week.ago
                  end

    # Get all users with this email frequency preference
    preferences_join = 'INNER JOIN base_user_preferences ' \
                       'ON base_user_preferences.base_user_id = base_users.id'
    users_with_frequency = BaseUser.joins(:user)
                                   .joins(preferences_join)
                                   .where("base_user_preferences.name = 'email_frequency' " \
                                          'AND base_user_preferences.value = ?', frequency)

    users_with_frequency.find_each do |base_user|
      next if base_user.user&.email.blank?

      send_digest_for_user(base_user.user.email, cutoff_time)
    end
  end

  private

  def send_digest_for_user(email, cutoff_time)
    notifications = PendingNotification.for_recipient(email).older_than(cutoff_time)

    return if notifications.empty?

    # Send digest email
    Notifications.notification_digest(email, notifications).deliver_now

    # Delete the notifications after sending
    notifications.destroy_all
  rescue StandardError => e
    Rails.logger.error("Failed to send digest for #{email}: #{e.message}")
  end
end
