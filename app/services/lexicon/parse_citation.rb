# frozen_string_literal: true

module Lexicon
  # Service to parse citation from Lexicon
  class ParseCitation < ApplicationService
    # @param list_item li element from html document representing a citation
    def call(list_item, from_publication)
      citation = LexCitation.new(status: :raw, raw: list_item.inner_html, from_publication: from_publication)

      # first bold element is the author
      b = list_item.at_css('b')
      citation.authors = b&.text
      # TODO: process possible links to author pages (in this case there should be an <a/> tag inside of <b/>)
      b.remove # removing bold tag to simplify further processing

      pages_pattern = /((?:עמ['׳]?\s*|p\.?\s*|pp\.?\s*)(\d+(?:[–\-־]\d+)?))/

      rest_text = list_item.text
      match = rest_text.match(pages_pattern)
      if match
        citation.pages = match[2] # The page numbers only
        rest_text = rest_text.gsub(match[1], '').strip # Remove the exact matched string
      end

      # removing trailing punctuation left after removal of pages, authors, etc.
      citation.title = rest_text.squish.gsub(/[.\s,]*\z/, '')
      citation
    end
  end
end
