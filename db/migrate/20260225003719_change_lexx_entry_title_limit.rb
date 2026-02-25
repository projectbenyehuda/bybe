# frozen_string_literal: true

# Lengthen lex_entries.title to 1024 characters.
# The full-text index on title is replaced with a prefix index (191 chars)
# because utf8mb4 varchar(1024) would exceed MySQL's 3072-byte index key limit.
# The index must be dropped before change_column because MySQL tries to rebuild
# it during the column resize and fails on key length.
class ChangeLexxEntryTitleLimit < ActiveRecord::Migration[8.0]
  def up
    remove_index :lex_entries, name: :index_lex_entries_on_title
    change_column :lex_entries, :title, :string, limit: 1024
    add_index :lex_entries, :title, name: :index_lex_entries_on_title, length: 191
  end

  def down
    remove_index :lex_entries, name: :index_lex_entries_on_title
    change_column :lex_entries, :title, :string, limit: 255
    add_index :lex_entries, :title, name: :index_lex_entries_on_title
  end
end
