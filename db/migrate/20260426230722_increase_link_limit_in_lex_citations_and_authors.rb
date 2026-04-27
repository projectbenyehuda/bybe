# frozen_string_literal: true

class IncreaseLinkLimitInLexCitationsAndAuthors < ActiveRecord::Migration[7.1]
  def change
    change_column :lex_citations, :link, :string, limit: 1024
    change_column :lex_citation_authors, :link, :string, limit: 1024
  end
end
