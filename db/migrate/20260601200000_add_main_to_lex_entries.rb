# frozen_string_literal: true

# Distinguishes main lexicon entries (shown in /lex) from secondary entries,
# which are ingested but only reachable via internal links from another entry.
class AddMainToLexEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :lex_entries, :main, :boolean, default: true, null: false

    # Backfill: legacy entries whose source PHP filename is numeric but NOT
    # exactly five digits (e.g. 02645001.php) are secondary entries.
    say_with_time 'Marking non-five-digit legacy entries as non-main' do
      LexEntry.reset_column_information
      LexEntry.joins(:lex_file)
              .where.not('lex_files.fname REGEXP ?', '^[0-9]{5}\\.php$')
              .update_all(main: false)
    end
  end

  def down
    remove_column :lex_entries, :main
  end
end
