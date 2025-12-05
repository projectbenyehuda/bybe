# frozen_string_literal: true

class MakeEntryIdNotNullInLexFiles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :lex_files, :lex_entry_id, false
  end
end
