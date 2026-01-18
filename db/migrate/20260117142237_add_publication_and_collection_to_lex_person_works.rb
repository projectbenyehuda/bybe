# frozen_string_literal: true

# Add publication and collection associations to LexPersonWork
# to link works to BYP Publications and Collections
class AddPublicationAndCollectionToLexPersonWorks < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_person_works, :publication_id, :integer, null: true
    add_column :lex_person_works, :collection_id, :integer, null: true

    add_index :lex_person_works, :publication_id
    add_index :lex_person_works, :collection_id

    add_foreign_key :lex_person_works, :publications
    add_foreign_key :lex_person_works, :collections
  end
end
