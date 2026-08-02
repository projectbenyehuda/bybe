# frozen_string_literal: true

module Lexicon
  # Shared helpers for turning an <a> tag of a legacy lexicon page into a text→link pair
  # (see LexiconHelper#apply_text_links), used when the surrounding text is stored as plain
  # text and the anchor would otherwise be lost.
  module TextLinkExtraction
    # Builds a { 'text' =>, 'entry_id' | 'url' => } pair, or nil when the anchor cannot be used
    # (blank text, blank/local-anchor href, or a link to a LexEntry that no longer exists).
    def build_text_link(text, href)
      target = text_link_target(href)
      return nil if text.blank? || target.nil?

      target.merge('text' => text)
    end

    # Lexicon links have already been rewritten to /lex/entries/:id by Lexicon::ProcessLinks,
    # so an href pointing there is stored as an entry reference; everything else is stored as a
    # plain URL. Hrefs that are still relative at this point are legacy paths ProcessLinks could
    # not resolve (e.g. an un-migrated NNNNN.php page): they are meaningless outside the old site,
    # and would be resolved against the entry's own path if stored, so they are dropped.
    def text_link_target(href)
      return nil if href.blank? || href.start_with?('#')

      entry_id = href_entry_id(href)
      return { 'entry_id' => entry_id } if entry_id.present? && LexEntry.exists?(id: entry_id)
      return nil if entry_id.present?

      href.match?(%r{\A(/|https?://|mailto:)}i) ? { 'url' => href } : nil
    end

    # The LexEntry id an href points at, or nil when it does not point at a lexicon entry.
    def href_entry_id(href)
      entries_path = Rails.application.routes.url_helpers.lexicon_entries_path
      match = href.to_s.match(%r{\A#{Regexp.escape(entries_path)}/(?<entry_id>\d+)})
      match && match[:entry_id].to_i
    end
  end
end
