# frozen_string_literal: true

class CreateLexCitationAuthors < ActiveRecord::Migration[8.0]
  def change
    create_table :lex_citation_authors do |t|
      t.timestamps
      t.references :lex_citation, null: false, foreign_key: true
      t.string :name
      t.string :link
      t.references :lex_person, foreign_key: true
    end

    execute <<~SQL
      insert into lex_citation_authors (lex_citation_id, name, created_at)
      select id, authors, created_at from lex_citations where authors is not null  
    SQL

    remove_column :lex_citations, :authors, :string
  end
end
