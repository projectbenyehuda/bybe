# frozen_string_literal: true

class AddIndexToLexEntriesMigrationItemCount < ActiveRecord::Migration[8.1]
  def change
    add_index :lex_entries, :migration_item_count
  end
end
