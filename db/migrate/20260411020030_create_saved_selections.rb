# frozen_string_literal: true

# Migration to create saved_selections table for mass update system
class CreateSavedSelections < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_selections do |t|
      t.string :name, null: false
      t.integer :user_id, null: false
      t.boolean :shared, null: false, default: false
      t.date :delete_after, null: false

      t.timestamps
    end

    add_index :saved_selections, :user_id
    add_index :saved_selections, :delete_after
  end
end
