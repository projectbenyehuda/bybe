# frozen_string_literal: true

# Link checking runs from a datacenter IP and cannot execute a bot challenge (Cloudflare and
# friends), so the 403 such a host answers with is a false negative, not a broken link. This flag
# records that third state -- checked, but no verdict reached -- so the verification UI can tell
# the editor to open the URL in a browser instead of showing a red broken-link warning.
# Named link_unverifiable on lex_citations to match its sibling link_http_status/link_checked_at.
class AddUnverifiableToLexLinksAndCitations < ActiveRecord::Migration[8.0]
  def change
    add_column :lex_links, :unverifiable, :boolean, default: false, null: false
    add_column :lex_citations, :link_unverifiable, :boolean, default: false, null: false
  end
end
