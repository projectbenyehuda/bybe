# frozen_string_literal: true

# Decides what happens to a recipient's buffered notifications when they stop using a throttled
# email frequency.
#
# NotificationDigestJob only visits users whose *current* preference is daily or weekly, so without
# this, rows buffered before the change are never sent and never deleted: they sit in
# pending_notifications indefinitely and the notifications are silently lost.
#
# The two exits differ deliberately:
# - 'unlimited' means "stop holding my mail", so the buffer is flushed as one last digest.
# - 'none' means "send me nothing", so flushing would mail someone who has just asked for silence.
#   The buffer is discarded instead.
class ResolveBufferedNotifications < ApplicationService
  def call(recipient_email:, new_frequency:)
    return if recipient_email.blank?

    case new_frequency
    when 'unlimited' then SendNotificationDigest.call(recipient_email: recipient_email)
    when 'none' then purge(recipient_email)
    end
  end

  private

  def purge(recipient_email)
    purged = PendingNotification.for_recipient(recipient_email).delete_all
    return if purged.zero?

    Rails.logger.info("Discarded #{purged} buffered notifications for #{recipient_email} (preference: none)")
  end
end
