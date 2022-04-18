class AddIndexByFnameToLexFile < ActiveRecord::Migration[5.2]
  def change
    add_index :lex_files, :fname, unique: true
  end
end
