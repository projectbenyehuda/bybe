# frozen_string_literal: true

class IncreaseLengthOfLinkInLexCitations < ActiveRecord::Migration[8.0]
  def change
    change_column :lex_citations, :link, :string, limit: 300
  end
end
