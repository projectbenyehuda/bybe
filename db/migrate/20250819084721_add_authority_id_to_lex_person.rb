# frozen_string_literal: true

class AddAuthorityIdToLexPerson < ActiveRecord::Migration[7.2]
  def change
    remove_column :lex_people, :person_id, :integer, if_exists: true
    add_belongs_to :lex_people, :authority, foreign_key: true, type: :integer, index: true, null: true, if_not_exists: true
  end
end
