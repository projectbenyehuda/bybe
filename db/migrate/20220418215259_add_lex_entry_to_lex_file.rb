class AddLexEntryToLexFile < ActiveRecord::Migration[5.2]
  def change
    add_reference :lex_files, :lex_entry, index: {:unique=>true}, foreign_key: true
  end
end
