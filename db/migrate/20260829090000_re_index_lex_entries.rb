# frozen_string_literal: true

# LexEntry bios were indexed as raw HTML; they are now indexed as plain text,
# so the existing documents have to be rebuilt.
class ReIndexLexEntries < ActiveRecord::Migration[8.0]
  def change
    say 'Reindexing Lexicon Entries...'
    LexEntriesIndex.reset!
  end
end
