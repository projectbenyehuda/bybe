# frozen_string_literal: true

class AddSeqnoToLexLinkedPeople < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_linked_people, :seqno, :integer

    execute <<~SQL
      create temporary table temp_lex_linked_people_seqno as
      select id,
             (
               select count(*)
               from lex_linked_people lp2
               where
                 lp2.lex_person_work_id = lp.lex_person_work_id
                 and lp2.id < lp.id
             ) + 1 as seqno
      from lex_linked_people lp
    SQL

    execute <<-SQL.squish
      update lex_linked_people lp
      set seqno = (select seqno from temp_lex_linked_people_seqno t where t.id = lp.id)
    SQL

    execute 'drop temporary table temp_lex_linked_people_seqno'
    change_column_null :lex_linked_people, :seqno, false
    add_index :lex_linked_people, %i(lex_person_work_id seqno), unique: true
  end
end
