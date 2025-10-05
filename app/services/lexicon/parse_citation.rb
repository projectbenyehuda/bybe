# frozen_string_literal: true

module Lexicon
  # Service to parse citation from Lexicon
  class ParseCitation < ApplicationService
    # @param list_item li element from html document representing a citation
    def call(list_item)
      citation = LexCitation.new(status: :raw, raw: list_item.inner_html)

      # first bold element is the author
      b = list_item.at_css('b')
      citation.authors = b&.text
      # TODO: process possible links to author pages (in this case there should be an <a/> tag inside of <b/>)
      b.remove # removing bold tag to simplify further processing

      # book name should be the text inside double quotes
      book = list_item.text
      book =~ /"(.*?)"/m
      citation.from_publication = Regexp.last_match(1)

      # pages are either the single number or range of numbers
      match = list_item.text.match(/עמ['׳]?\s*(\d+(?:[–\-־]\d+)?)/)
      citation.pages = match[1] if match

      citation
    end
  end
end
