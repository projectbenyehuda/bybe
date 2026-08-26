# frozen_string_literal: true

# ActiveJob to send digest emails for users with daily/weekly email frequency preferences
class NotificationDigestJob < ApplicationJob
  # How recently a recipient must have received a digest for this run to skip them. Deliberately a
  # little shorter than the nominal period, so that ordinary scheduler jitter -- a run firing a few
  # seconds earlier than the previous one did -- cannot swallow a whole period's digest.
  MIN_INTERVAL_BETWEEN_DIGESTS = { 'daily' => 23.hours, 'weekly' => 6.days }.freeze

  def perform(frequency)
    # Validate frequency parameter
    unless MIN_INTERVAL_BETWEEN_DIGESTS.key?(frequency)
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

      SendNotificationDigest.call(recipient_email: email,
                                  min_interval: MIN_INTERVAL_BETWEEN_DIGESTS.fetch(frequency))
    end
  end
end
