# frozen_string_literal: true

class AddColumnsToLexCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_citations, :raw, :text, if_not_exists: true
    add_column :lex_citations, :status, :integer, null: false, if_not_exists: true
    add_column :lex_citations, :notes, :text, if_not_exists: true
  end
end
