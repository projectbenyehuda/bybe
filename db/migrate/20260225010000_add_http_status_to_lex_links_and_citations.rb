# frozen_string_literal: true

# Adds http_status to lex_links and link_http_status to lex_citations to
# record the HTTP status code returned when checking each link during migration.
class AddHttpStatusToLexLinksAndCitations < ActiveRecord::Migration[8.0]
  def change
    # Store the HTTP status code returned when checking the link during migration.
    # nil = not yet checked, 200 = OK, 4xx/5xx = broken.
    add_column :lex_links, :http_status, :integer, null: true
    add_column :lex_citations, :link_http_status, :integer, null: true
  end
end
