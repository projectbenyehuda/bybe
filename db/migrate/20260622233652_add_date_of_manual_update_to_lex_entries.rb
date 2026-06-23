# frozen_string_literal: true

class AddDateOfManualUpdateToLexEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_entries, :date_of_manual_update, :string
  end
end
