# frozen_string_literal: true

class AddSubjectToLexCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_citations, :subject, :string
    add_reference :lex_citations, :lex_person, foreign_key: true, index: true, null: false
  end
end
