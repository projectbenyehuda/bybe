# frozen_string_literal: true

# The original create_lex_legacy_links migration enforced old_path uniqueness.
# Migration 20260118 removed it, leaving duplicates in the data.
# This migration deduplicates and restores the unique constraint.
class RestoreUniquenessOnLexLegacyLinksOldPath < ActiveRecord::Migration[8.1]
  def up
    # Delete rows that are not the first (lowest id) for their old_path.
    execute <<~SQL.squish
      DELETE FROM lex_legacy_links
      WHERE id NOT IN (
        SELECT min_id FROM (
          SELECT MIN(id) AS min_id FROM lex_legacy_links GROUP BY old_path
        ) AS keepers
      )
    SQL

    add_index :lex_legacy_links, :old_path, name: 'index_lex_legacy_links_on_old_path', unique: true
  end

  def down
    change_table :lex_legacy_links, bulk: true do |t|
      t.remove_index name: 'index_lex_legacy_links_on_old_path'
      t.index :old_path, name: 'index_lex_legacy_links_on_old_path'
    end
  end
end
