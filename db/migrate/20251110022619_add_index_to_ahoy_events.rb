# frozen_string_literal: true

class AddIndexToAhoyEvents < ActiveRecord::Migration[8.0]
  def change
    add_index :ahoy_events, [:time, :name, :item_type, :item_id]
  end
end
