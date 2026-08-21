# frozen_string_literal: true

class CreateLexPersonWorks < ActiveRecord::Migration[8.0]
  def change
    create_table :lex_person_works do |t|
      t.references :lex_person, null: false, foreign_key: true
      t.references :lex_publication, foreign_key: true
      t.string :title, null: false
      t.timestamps
      t.string :publisher
      t.string :publication_date
      t.string :publication_place
      t.string :comment
      t.integer :work_type, null: false
    end
  end
end
