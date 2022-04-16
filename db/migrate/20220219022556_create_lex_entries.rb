class CreateLexEntries < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_entries do |t|
      t.string :title
      t.integer :status
      t.references :lex_person, foreign_key: true
      t.references :lex_publication, foreign_key: true

      t.timestamps
    end
    add_index :lex_entries, :title
    add_index :lex_entries, :status
  end
end
