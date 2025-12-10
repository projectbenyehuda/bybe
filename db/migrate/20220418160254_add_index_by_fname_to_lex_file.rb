class AddIndexByFnameToLexFile < ActiveRecord::Migration[5.2]
  def change
    add_index :lex_files, :fname, unique: true, if_not_exists: true
  end
end
