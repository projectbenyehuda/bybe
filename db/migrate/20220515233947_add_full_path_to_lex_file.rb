class AddFullPathToLexFile < ActiveRecord::Migration[5.2]
  def change
    add_column :lex_files, :full_path, :string, if_not_exists: true
  end
end
