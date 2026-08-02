# frozen_string_literal: true

# Shared add/remove handling for the text→link pairs stored in a JSON column
# (LexPersonWork#title_links / #comment_links, LexCitation#text_links).
# A pair is either { 'text' => ..., 'entry_id' => ... } or { 'text' => ..., 'url' => ... };
# see LexiconHelper#apply_text_links for how they are rendered.
module TextLinksConcern
  extend ActiveSupport::Concern

  private

  def add_text_link_to(record, field)
    pair = text_link_pair
    return head :unprocessable_content if pair.nil?

    links = Array(record.public_send(field))
    # a given text can only be linked once, since it is substituted by first occurrence
    record.update!(field => links + [pair]) if links.none? { |link| link['text'] == pair['text'] }

    head :ok
  end

  def remove_text_link_from(record, field)
    # Parse the :index param strictly: a non-numeric value ('abc'.to_i == 0) must not
    # silently delete the first link.
    index = Integer(params[:index], exception: false)
    return head :unprocessable_content if index.nil?

    links = Array(record.public_send(field))
    links.delete_at(index) if index >= 0 && index < links.size
    record.update!(field => links.presence)

    head :ok
  end

  # Builds a link pair from the :text plus either the :entry_id or the :url param,
  # returning nil when the input cannot form a usable pair.
  def text_link_pair
    text = params[:text].to_s.strip
    return nil if text.blank?

    entry_id = params[:entry_id].presence.to_i
    if entry_id.positive?
      return nil unless LexEntry.exists?(id: entry_id)

      return { 'text' => text, 'entry_id' => entry_id }
    end

    url = params[:url].to_s.strip
    # Same allowlist the ingestion path applies, rather than a denylist of script-bearing
    # schemes: the url ends up in an href, so anything not known-inert is refused.
    # (This subsumes the explicit javascript: check of the Copilot autofix it replaces.)
    return nil unless url.match?(Lexicon::TextLinkExtraction::ALLOWED_URL_PATTERN)

    { 'text' => text, 'url' => url }
  end
end
