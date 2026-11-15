# frozen_string_literal: true

# A legacy works section may split the works of one kind under sub-headings of its own: 00421.php
# lists its original works under שירה ופרוזה and עיון, and 01661.php its edited works under
# עריכת תרגום - ספרי עיון, עריכת מקור - ספרי עיון and so on. The migration threw those headings
# away. A LexPersonWorkGroup is one such sub-heading: a named, ordered bucket of a person's works
# of one work type.
class CreateLexPersonWorkGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :lex_person_work_groups do |t|
      t.references :lex_person, null: false, foreign_key: true
      t.integer :work_type, null: false
      t.string :title, null: false
      t.integer :seqno, null: false
      t.timestamps
    end

    # One sub-heading of a given name per section: two indistinguishable headings under one work
    # type are something an editor could not tell apart.
    add_index :lex_person_work_groups, %i(lex_person_id work_type title),
              unique: true, name: 'index_lex_person_work_groups_on_person_type_and_title'

    add_reference :lex_person_works, :lex_person_work_group, null: true, foreign_key: true
  end
end
