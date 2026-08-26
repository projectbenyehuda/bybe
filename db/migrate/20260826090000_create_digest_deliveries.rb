# frozen_string_literal: true

# Per-recipient watermark for NotificationDigestJob, so that "at most one email per period" is
# enforced per recipient instead of resting on the scheduler firing exactly once per period.
class CreateDigestDeliveries < ActiveRecord::Migration[8.1]
  # No timestamps: last_digest_sent_at is the row's only fact, and an updated_at would be an exact
  # duplicate of it.
  # rubocop:disable Rails/CreateTableWithTimestamps
  def change
    create_table :digest_deliveries, if_not_exists: true do |t|
      t.string :recipient_email, null: false
      t.datetime :last_digest_sent_at, null: false

      t.index :recipient_email, unique: true
    end
  end
  # rubocop:enable Rails/CreateTableWithTimestamps
end
