# frozen_string_literal: true

class AddLegacyFilenameToLexEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_entries, :legacy_filename, :string
  end
end
