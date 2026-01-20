# frozen_string_literal: true

class RemoveFieldsFromLexCitations < ActiveRecord::Migration[8.0]
  def change
    remove_column :lex_citations, :status, :integer
    remove_column :lex_citations, :raw, :string
  end
end
