# frozen_string_literal: true

class AddMigrationItemCountToLexEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_entries, :migration_item_count, :integer
  end
end
