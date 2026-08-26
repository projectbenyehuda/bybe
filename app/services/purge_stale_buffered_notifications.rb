# frozen_string_literal: true

# Backstop against unbounded growth of pending_notifications.
#
# The buffer is keyed on an email address and has no foreign key, so a row can outlive the
# preference that created it and even the account itself (a destroyed User leaves its rows behind).
# The ordinary exits are NotificationDigestJob and ResolveBufferedNotifications; this sweeper
# catches whatever neither of them will ever visit.
class PurgeStaleBufferedNotifications < ApplicationService
  # Twice the longest digest period, so that any row a live schedule would still deliver is safe.
  CEILING = 2.weeks

  def call
    purged = PendingNotification.older_than(CEILING.ago).delete_all
    Rails.logger.info("Purged #{purged} stale buffered notifications") if purged.positive?
    purged
  end
end
