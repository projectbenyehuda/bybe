# frozen_string_literal: true

module Lexicon
  # Service to extract citations from Lexicon entry php file
  class ExtractCitations < ApplicationService
    include HtmlUtils

    def call(html_doc)
      header = header_element(html_doc)
      return [] if header.nil?

      # The next element should be a 'font' tag containing all citations. Sometimes there could be one or more blank
      # paragraphs before it, so we need to skip them.
      citations_node = next_element_skipping_blank(header)

      return [] if citations_node&.name != 'font'

      result = Lexicon::ParseCitations.call(citations_node.inner_html)

      # We used to delete parsed nodes earlier, but it turned out in some files citations node contains other
      # sections (e.g. Links block, so we cannot simply remove it)
      # header.remove
      # citations_node.remove
      result
    end

    private

    def header_element(html_doc)
      header = html_doc.at_css("a[name=\"Bib.\"]")

      return nil if header.nil?

      header = header.parent # should be a <font> tag

      if header.parent.name == 'p' # normally font tag should be wrapped in a paragraph, but sometimes it's not
        header = header.parent
      end

      # this can happen if citations header was added at the end of Works list (malformed document)
      if header.next_element.nil?
        header = header.parent
      end

      header
    end
  end
end
