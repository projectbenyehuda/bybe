# frozen_string_literal: true

class AddSortTitleToLexEntry < ActiveRecord::Migration[6.1]
  def change
    add_column :lex_entries, :sort_title, :string
    add_index :lex_entries, :sort_title
  end
end
