# frozen_string_literal: true

# Holds the Wayback Machine snapshot of a link that link-checking found broken (see
# Lexicon::WaybackLookup), so verifiers can open or adopt it without searching the archive.
# A snapshot URL is the original prefixed with https://web.archive.org/web/<timestamp>/, so
# lex_links.url is widened to match lex_citations.link: adopting a snapshot must not overflow it.
class AddArchiveUrlToLexLinksAndCitations < ActiveRecord::Migration[8.0]
  def up
    change_table :lex_links, bulk: true do |t|
      t.change :url, :string, limit: 1024
      t.string :archive_url, limit: 1024
    end
    add_column :lex_citations, :link_archive_url, :string, limit: 1024
  end

  def down
    remove_column :lex_citations, :link_archive_url
    change_table :lex_links, bulk: true do |t|
      t.remove :archive_url
      t.change :url, :string
    end
  end
end
