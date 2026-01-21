# frozen_string_literal: true

class MakeOldPathUniqueAgain < ActiveRecord::Migration[8.0]
  def change
    execute <<~SQL
      CREATE TEMPORARY TABLE tempids AS 
      select id from lex_legacy_links l1
      where exists (select 1 from lex_legacy_links l2 where l2.old_path = l1.old_path and l1.id > l2.id)
    SQL

    execute 'DELETE FROM lex_legacy_links where id in (select id from tempids)'
    execute 'DROP TEMPORARY TABLE IF EXISTS tempids'

    remove_index :lex_legacy_links, :old_path
    add_index :lex_legacy_links, :old_path, unique: true
  end
end
