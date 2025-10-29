class CreatePendingNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :pending_notifications do |t|
      t.string :recipient_email
      t.string :notification_type
      t.text :notification_data
      t.datetime :created_at

      t.timestamps
    end
  end
end
