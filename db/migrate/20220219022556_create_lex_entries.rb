class CreateLexEntries < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_entries, if_not_exists: true do |t|
      t.string :title
      t.integer :status
      t.references :lex_person, foreign_key: true
      t.references :lex_publication, foreign_key: true

      t.timestamps
    end
    add_index :lex_entries, :title, if_not_exists: true
    add_index :lex_entries, :status, if_not_exists: true
  end
end
