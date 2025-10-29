# frozen_string_literal: true

module NotificationsHelper
  # Render a single notification in a digest email
  def render_notification(notification)
    data = notification.notification_data
    mailer_class = data['mailer_class'].constantize
    mailer_method = data['mailer_method'].to_sym
    args = data['args']

    # Create the mailer and render its content
    mailer = mailer_class.public_send(mailer_method, *args)
    mailer.body.to_s.html_safe
  rescue StandardError => e
    Rails.logger.error("Failed to render notification #{notification.id}: #{e.message}")
    content_tag(:p, t(:notification_render_error))
  end

  # Generate email footer with preferences link for registered users
  def email_footer_html(recipient_email = nil)
    base_footer = t(:email_footer_html)

    # Check if recipient is a registered user
    user = User.find_by(email: recipient_email) if recipient_email.present?

    if user
      preferences_link = link_to(t(:manage_email_preferences), edit_user_preferences_url(protocol: 'https'))
      "#{base_footer}\n\n#{preferences_link}".html_safe
    else
      signup_text = t(:email_footer_signup_invitation)
      "#{base_footer}\n\n#{signup_text}".html_safe
    end
  end
end
