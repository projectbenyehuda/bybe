# frozen_string_literal: true

# Service to handle email notification queuing based on user preferences
class NotificationService < ApplicationService
  # Send or queue a notification based on user's email_frequency preference
  # @param mailer_class [Class] The mailer class (e.g., Notifications)
  # @param mailer_method [Symbol] The mailer method to call (e.g., :proof_fixed)
  # @param recipient_email [String] The recipient's email address
  # @param args [Array] Arguments to pass to the mailer method
  def call(mailer_class:, mailer_method:, recipient_email:, args: [])
    return if recipient_email.blank?

    base_user = find_base_user_by_email(recipient_email)
    email_frequency = base_user&.get_preference(:email_frequency) || 'unlimited'

    case email_frequency
    when 'none'
      # Don't send or queue the notification
      Rails.logger.info("Notification suppressed for #{recipient_email} (preference: none)")
    when 'unlimited'
      # Send immediately
      mailer_class.public_send(mailer_method, *args).deliver_now
    when 'daily', 'weekly'
      # Queue for later delivery
      queue_notification(
        recipient_email: recipient_email,
        notification_type: "#{mailer_class.name}##{mailer_method}",
        notification_data: { mailer_class: mailer_class.name, mailer_method: mailer_method.to_s, args: args }
      )
    end
  end

  private

  def find_base_user_by_email(email)
    # First try to find a user with this email
    user = User.find_by(email: email)
    return user.base_user if user&.base_user

    # If no user found with this email, return nil (non-user recipient)
    nil
  end

  def queue_notification(recipient_email:, notification_type:, notification_data:)
    PendingNotification.create!(
      recipient_email: recipient_email,
      notification_type: notification_type,
      notification_data: notification_data
    )
    Rails.logger.info("Notification queued for #{recipient_email}: #{notification_type}")
  end
end
