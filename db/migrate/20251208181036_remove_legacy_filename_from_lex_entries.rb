# frozen_string_literal: true

class RemoveLegacyFilenameFromLexEntries < ActiveRecord::Migration[8.0]
  def change
    remove_column :lex_entries, :legacy_filename, :string
  end
end
