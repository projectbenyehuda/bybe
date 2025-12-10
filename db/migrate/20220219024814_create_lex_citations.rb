class CreateLexCitations < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_citations, if_not_exists: true do |t|
      t.string :title
      t.string :from_publication
      t.string :authors
      t.string :pages
      t.string :link
      t.references :item, polymorphic: true
      t.references :manifestation, foreign_key: true, type: :integer

      t.timestamps
    end
    add_index :lex_citations, :title, if_not_exists: true
    add_index :lex_citations, :authors, if_not_exists: true
  end
end
