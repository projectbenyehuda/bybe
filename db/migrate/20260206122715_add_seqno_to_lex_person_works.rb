# frozen_string_literal: true

class AddSeqnoToLexPersonWorks < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_person_works, :seqno, :integer

    execute <<~SQL
        create temporary table temp_lex_person_works_seqno as 
        select id,
               (
                 select count(*) from lex_person_works w2
                 where
                   w2.lex_person_id = w.lex_person_id
                   and w2.work_type = w.work_type
                   and w2.id < w.id
               ) + 1 as seqno
        from lex_person_works w
    SQL

    execute <<-SQL.squish
      update lex_person_works w 
      set seqno = (select seqno from temp_lex_person_works_seqno t where t.id = w.id)
    SQL

    execute 'drop temporary table temp_lex_person_works_seqno'
    change_column_null :lex_person_works, :seqno, false
  end
end
