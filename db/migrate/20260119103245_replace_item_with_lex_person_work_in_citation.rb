# frozen_string_literal: true

class ReplaceItemWithLexPersonWorkInCitation < ActiveRecord::Migration[8.0]
  def change
    remove_reference :lex_citations, :item, polymorphic: true
    add_reference :lex_citations, :lex_person_work, foreign_key: true, index: true
  end
end
