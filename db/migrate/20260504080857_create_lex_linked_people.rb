# frozen_string_literal: true

class CreateLexLinkedPeople < ActiveRecord::Migration[8.1]
  def change
    create_table :lex_linked_people do |t|
      t.belongs_to :lex_person_work, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.belongs_to :person_lex_entry, foreign_key: { to_table: :lex_entries }, index: true
      t.integer :link_type, null: false
      t.integer :seqno, null: false
      t.timestamps
    end
  end
end
