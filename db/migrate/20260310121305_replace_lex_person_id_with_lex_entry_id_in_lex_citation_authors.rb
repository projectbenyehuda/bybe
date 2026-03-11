# frozen_string_literal: true

class ReplaceLexPersonIdWithLexEntryIdInLexCitationAuthors < ActiveRecord::Migration[8.0]
  def change
    remove_index :lex_citation_authors, %i(lex_citation_id lex_person_id),
                 name: 'idx_on_lex_citation_id_lex_person_id_df9730c730'
    remove_foreign_key :lex_citation_authors, :lex_people
    remove_column :lex_citation_authors, :lex_person_id, :bigint

    add_reference :lex_citation_authors, :lex_entry, foreign_key: true
    add_index :lex_citation_authors, %i(lex_citation_id lex_entry_id), unique: true
  end
end
