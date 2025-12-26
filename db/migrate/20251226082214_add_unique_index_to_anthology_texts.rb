# frozen_string_literal: true

class AddUniqueIndexToAnthologyTexts < ActiveRecord::Migration[8.0]
  def change
    execute <<~SQL
      CREATE TEMPORARY TABLE tempids AS select id
          from anthology_texts a1
          where a1.manifestation_id is not null
                AND EXISTS (
                  SELECT 1 FROM anthology_texts a2
                  WHERE a2.anthology_id = a1.anthology_id
                        AND a2.manifestation_id = a1.manifestation_id
                        AND a2.id < a1.id
                )
    SQL

    execute 'DELETE FROM anthology_texts where id in (select id from tempids)'
    execute 'DROP TEMPORARY TABLE IF EXISTS tempids'

    add_index :anthology_texts, [:anthology_id, :manifestation_id], unique: true
  end
end
