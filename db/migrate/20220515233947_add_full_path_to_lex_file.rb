class AddFullPathToLexFile < ActiveRecord::Migration[5.2]
  def change
    add_column :lex_files, :full_path, :string
  end
end
