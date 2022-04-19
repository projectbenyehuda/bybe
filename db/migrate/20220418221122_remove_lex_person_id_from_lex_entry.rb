class RemoveLexPersonIdFromLexEntry < ActiveRecord::Migration[5.2]
  def change
    remove_column :lex_entries, :lex_person_id, :bigint
    remove_column :lex_entries, :lex_publication_id, :bigint
  end
end
