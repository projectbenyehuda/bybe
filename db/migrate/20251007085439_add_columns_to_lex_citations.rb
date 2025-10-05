# frozen_string_literal: true

class AddColumnsToLexCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_citations, :raw, :text
    add_column :lex_citations, :status, :integer, null: false
    add_column :lex_citations, :notes, :text
  end
end
