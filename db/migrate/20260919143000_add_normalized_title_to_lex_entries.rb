# frozen_string_literal: true

# The lexicon's name filters run as MySQL LIKE against lex_entries.title, so a search only
# matched when its punctuation and pointing happened to agree with the stored title. Wrapping
# the ~60 REPLACE() calls it would take to normalize title in SQL around every row would be
# both unreadable and unindexable, so the normalized form is stored alongside it instead.
class AddNormalizedTitleToLexEntries < ActiveRecord::Migration[8.0]
  def up
    # Deliberately unindexed: both callers search for a substring, and a leading-wildcard
    # LIKE '%...%' cannot use a B-tree index -- EXPLAIN does not even list one as a candidate
    # key. An index here would only cost storage and write time on every title change.
    add_column :lex_entries, :normalized_title, :string, limit: 1024

    LexEntry.reset_column_information
    # update_column, so that neither validations nor the SortedTitle callbacks touch rows that
    # the backfill is only meant to add a derived column to.
    LexEntry.find_each do |entry|
      entry.update_column(:normalized_title, Lexicon::NormalizeSearchText.call(entry.title))
    end
  end

  def down
    remove_column :lex_entries, :normalized_title
  end
end
