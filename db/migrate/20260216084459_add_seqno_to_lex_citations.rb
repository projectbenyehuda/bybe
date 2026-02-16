# frozen_string_literal: true

class AddSeqnoToLexCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_citations, :seqno, :integer

    execute <<~SQL
        create temporary table temp_lex_citations_seqno as 
        select id,
               (
                 select count(*)
                 from lex_citations c2
                 where
                     c2.lex_person_id = c.lex_person_id
                     and (c2.subject = c.subject)
                     and (c2.lex_person_work_id = c.lex_person_work_id)
                     and c2.id < c.id
               ) + 1 as seqno
        from lex_citations c
    SQL

    execute <<-SQL.squish
      update lex_citations c 
      set seqno = (select seqno from temp_lex_citations_seqno t where t.id = c.id)
    SQL

    execute 'drop temporary table temp_lex_citations_seqno'
    change_column_null :lex_citations, :seqno, false
  end
end
