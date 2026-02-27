# frozen_string_literal: true

class AddOtherDesignationToLexEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_entries, :other_designation, :string, limit: 1024
  end
end
