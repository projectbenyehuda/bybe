# frozen_string_literal: true

# Per-key API usage counters, incremented by V1::Validations::AuthKey on every accepted call
class AddUsageTrackingToApiKeys < ActiveRecord::Migration[8.0]
  def change
    change_table :api_keys, bulk: true do |t|
      t.bigint :calls_count, null: false, default: 0
      t.datetime :last_used_at
    end
  end
end
