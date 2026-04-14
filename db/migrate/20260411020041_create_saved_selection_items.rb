# frozen_string_literal: true

# Migration to create saved_selection_items table for mass update system
class CreateSavedSelectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_selection_items do |t|
      t.integer :saved_selection_id, null: false
      t.string :item_type, null: false
      t.integer :item_id, null: false

      t.timestamps
    end

    add_index :saved_selection_items, :saved_selection_id
    add_index :saved_selection_items, %i(item_type item_id)
  end
end
