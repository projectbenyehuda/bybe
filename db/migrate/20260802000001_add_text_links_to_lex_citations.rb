# frozen_string_literal: true

class AddTextLinksToLexCitations < ActiveRecord::Migration[8.1]
  def change
    add_column :lex_citations, :text_links, :json
  end
end
