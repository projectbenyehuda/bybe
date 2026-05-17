# frozen_string_literal: true

# Verified status (105) has no distinct meaning from published (1); collapse them.
class MigrateVerifiedEntriesToPublished < ActiveRecord::Migration[8.1]
  def up
    execute 'UPDATE lex_entries SET status = 1 WHERE status = 105'
  end

  def down
    # Cannot reliably restore the original verified status after collapsing to published.
    raise ActiveRecord::IrreversibleMigration
  end
end
