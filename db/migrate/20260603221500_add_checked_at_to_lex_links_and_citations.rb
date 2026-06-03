# frozen_string_literal: true

# Adds a "checked at" timestamp so we can distinguish a link that was checked
# and found unreachable (status nil) from one that has never been checked.
# Both used to be represented by a nil http_status, which meant defunct/dead
# hosts were silently treated as healthy.
class AddCheckedAtToLexLinksAndCitations < ActiveRecord::Migration[8.1]
  def up
    add_column :lex_citations, :link_checked_at, :datetime
    add_column :lex_links, :checked_at, :datetime

    # Backfill: rows that already have a stored status were definitely checked,
    # so preserve their existing broken/healthy flagging. Rows with a nil status
    # are ambiguous (never checked vs. checked-and-failed) and are left NULL so
    # they get an authoritative result on the next check run.
    execute <<~SQL.squish
      UPDATE lex_citations SET link_checked_at = updated_at WHERE link_http_status IS NOT NULL
    SQL
    execute <<~SQL.squish
      UPDATE lex_links SET checked_at = updated_at WHERE http_status IS NOT NULL
    SQL
  end

  def down
    remove_column :lex_citations, :link_checked_at
    remove_column :lex_links, :checked_at
  end
end
