class CreateLexFiles < ActiveRecord::Migration[5.2]
  def change
    create_table :lex_files, if_not_exists: true do |t|
      t.string :fname
      t.integer :status
      t.string :title
      t.integer :entrytype
      t.text :comments

      t.timestamps
    end
    add_index :lex_files, :status, if_not_exists: true
    add_index :lex_files, :entrytype, if_not_exists: true
  end
end
