# frozen_string_literal: true

class RemoveRedundantIndexFromAhoyEvents < ActiveRecord::Migration[8.0]
  def change
    remove_index :ahoy_events, %i(item_id item_type name),  if_exists: true
  end
end
