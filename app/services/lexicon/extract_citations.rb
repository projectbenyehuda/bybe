# frozen_string_literal: true

module Lexicon
  # Service to extract citations from Lexicon entry php file
  class ExtractCitations < ApplicationService
    CITATIONS_HEADER_MALE = 'על המחבר ויצירתו:'
    CITATIONS_HEADER_FEMALE = 'על המחברת ויצירתה:'

    def call(html_doc)
      header = header_element(html_doc, CITATIONS_HEADER_MALE)
      header = header_element(html_doc, CITATIONS_HEADER_FEMALE) if header.nil?
      return if header.nil?

      # The next element should be a 'font' tag containing all citations. Sometimes there could be one or more blank
      # paragraphs before it, so we need to skip them.
      citations_node = header.next_element

      while citations_node.name != 'font' && citations_node.text.blank? do
        next_elem = citations_node = citations_node.next_element
        citations_node.remove
        citations_node = next_elem
      end

      return [] if citations_node&.name != 'font'

      result = ParseCitations.call(citations_node.inner_html)
      # remove header and citations node to simplify further processing
      header.remove
      citations_node.remove

      result
    end

    private

    def header_element(html_doc, header)
      header = html_doc.xpath("//a[contains(., \"#{header}\")]").first

      if header.present?
        header = header.parent # should be a <font> tag

        if header.parent.name == 'p' # normally font tag should be wrapped in a paragraph, but sometimes it's not
          header = header.parent
        end
      end

      header
    end

    # it always starts with the author (not the LexPerson, the author of the text *about* this LexPerson), then the name
    # of the article/text, then the publication it was published in, then date and page number.
    def parse_citations(list, subject)
      result = []
      list.element_children.each do |li|
        next unless li.name == 'li'

        result << ParseCitation.call(li, subject)
      end

      result
    end
  end
end
