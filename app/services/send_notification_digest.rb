# frozen_string_literal: true

# Drains everything currently buffered for one recipient into a single digest email and clears the
# buffer. Shared by NotificationDigestJob (the scheduled, once-per-period drain) and by
# ResolveBufferedNotifications (the one-off drain when a user stops using a throttled frequency).
class SendNotificationDigest < ApplicationService
  # @param recipient_email [String] address the buffer is keyed on
  # @param min_interval [ActiveSupport::Duration, nil] do nothing if this recipient was already sent
  #   a digest within this interval. nil sends regardless, for one-off flushes.
  def call(recipient_email:, min_interval: nil)
    return if recipient_email.blank?

    # Without this watermark the once-per-period promise would rest entirely on the scheduler firing
    # exactly once per period, which a manual re-run, a redeploy, a second app instance or a
    # backfill all break -- each of them sending every daily recipient a second full email.
    if min_interval.present? && DigestDelivery.sent_within?(recipient_email, min_interval)
      Rails.logger.info("Skipping digest for #{recipient_email}: one was already sent this period")
      return
    end

    drain(recipient_email)
  rescue StandardError => e
    # Deliberate: on a failed delivery the rows stay buffered and the next run retries them. Do not
    # "fix" this into a delete-always -- that would silently lose the recipient's notifications.
    Rails.logger.error("Failed to send digest for #{recipient_email}: #{e.message}")
  end

  private

  # Drains everything currently buffered, regardless of age: the once-per-period guarantee comes
  # from the watermark above, not from an age filter. Filtering by age here only bought a full extra
  # period of delivery latency.
  def drain(recipient_email)
    pending = PendingNotification.for_recipient(recipient_email).to_a

    return if pending.empty?

    renderable, unresolvable = pending.partition(&:resolvable?)

    # A notification referring to a since-deleted record can never render. Drop it, so that it does
    # not fail again on every subsequent run and block this recipient's other notifications.
    delete_notifications(unresolvable)

    return if renderable.empty?

    Notifications.notification_digest(recipient_email, renderable).deliver_now

    # The drain and the watermark write stand or fall together: rows may never be deleted without
    # the watermark recording why. The send itself is of course outside the transaction and cannot
    # be rolled back, so a crash between it and this block re-sends the digest on the next run -- a
    # duplicate, which is the failure direction we want.
    ApplicationRecord.transaction do
      delete_notifications(renderable)
      DigestDelivery.record!(recipient_email)
    end
  end

  def delete_notifications(notifications)
    return if notifications.empty?

    PendingNotification.where(id: notifications.map(&:id)).delete_all
  end
end
