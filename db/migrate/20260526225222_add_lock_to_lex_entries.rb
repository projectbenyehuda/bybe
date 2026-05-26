# frozen_string_literal: true

# Adds lock fields to lex_entries to prevent concurrent edits
class AddLockToLexEntries < ActiveRecord::Migration[8.1]
  def change
    change_table :lex_entries, bulk: true do |t|
      t.datetime :locked_at
      t.bigint :locked_by_user_id
      t.index :locked_by_user_id
    end
  end
end
