# frozen_string_literal: true

class CreateLegacyUrls < ActiveRecord::Migration[8.0]
  def change
    create_table :legacy_urls do |t|
      t.string :from_url, null: false
      t.string :target_type
      t.integer :target_id
      t.string :description

      t.timestamps
    end

    add_index :legacy_urls, :from_url, unique: true
    add_index :legacy_urls, %i[target_type target_id]
  end
end
