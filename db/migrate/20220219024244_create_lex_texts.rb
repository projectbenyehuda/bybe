class CreateLexTexts < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_texts do |t|
      t.string :title
      t.string :authors
      t.string :pages
      t.references :lex_publication, foreign_key: true
      t.references :lex_issue, foreign_key: true
      t.references :manifestation, foreign_key: true, type: :integer

      t.timestamps
    end
    add_index :lex_texts, :title
  end
end
