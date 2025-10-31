class CreatePendingNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :pending_notifications do |t|
      t.string :recipient_email, null: false
      t.string :notification_type, null: false
      t.text :notification_data
      t.datetime :created_at, null: false

      t.index :recipient_email
      t.index [:recipient_email, :created_at]
    end
  end
end
