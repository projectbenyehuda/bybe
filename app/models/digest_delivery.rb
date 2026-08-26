# frozen_string_literal: true

# Records when each recipient was last sent a notification digest, so that a second run of
# NotificationDigestJob within the same period (a manual re-run, a redeploy that re-fires the
# recurring entry, a backfill after an outage) does not send a second full email.
#
# Keyed on the email address rather than a user id, to match pending_notifications, which
# deliberately keys on the address so that recipients without an account still work.
class DigestDelivery < ApplicationRecord
  validates :recipient_email, :last_digest_sent_at, presence: true

  def self.sent_within?(recipient_email, interval)
    where(recipient_email: recipient_email).exists?(['last_digest_sent_at > ?', interval.ago])
  end

  # Two jobs racing on the same recipient will both pass sent_within? and one will lose here on the
  # unique index. That is deliberate: the loser's transaction rolls back, so its rows stay buffered
  # and are retried, rather than being dropped.
  def self.record!(recipient_email, sent_at = Time.current)
    delivery = find_or_initialize_by(recipient_email: recipient_email)
    delivery.last_digest_sent_at = sent_at
    delivery.save!
  end
end
