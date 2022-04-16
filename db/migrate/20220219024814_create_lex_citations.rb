class CreateLexCitations < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_citations do |t|
      t.string :title
      t.string :from_publication
      t.string :authors
      t.string :pages
      t.string :link
      t.references :item, polymorphic: true
      t.references :manifestation, foreign_key: true, type: :integer

      t.timestamps
    end
    add_index :lex_citations, :title
    add_index :lex_citations, :authors
  end
end
