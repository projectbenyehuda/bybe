# frozen_string_literal: true

module Lexicon
  # Utility methods for HTML processing to use them during PHP files parsing
  module HtmlUtils
    # Encoding libxml2 falls back to when a document declares no charset at all.
    # Legacy lexicon files are UTF-8, so that fallback silently mangles Hebrew into
    # mojibake ('נ' -> '× ', 'ת' -> '×ª', ...) rather than failing loudly.
    FALLBACK_ENCODING = 'ISO-8859-1'

    # Elements that render something of their own, so a table holding one is not empty
    # even when it has no text.
    VISIBLE_EMPTY_ELEMENTS = 'img, hr, iframe, embed, object, video, audio, input'

    # The named anchors that open a section of a legacy person entry, in document order.
    WORKS_ANCHOR = 'Books'
    CITATIONS_ANCHOR = 'Bib.'
    LINKS_ANCHOR = 'links'
    SECTION_ANCHORS = [WORKS_ANCHOR, CITATIONS_ANCHOR, LINKS_ANCHOR].freeze
    SECTION_ANCHOR_SELECTOR = SECTION_ANCHORS.map { |name| %(a[name="#{name}"]) }.join(', ')

    # Inline elements a section anchor is wrapped in. The wrapper carrying the section's
    # content as its following siblings is the outermost of these, so we climb out of all
    # of them when locating a header.
    HEADER_WRAPPERS = %w(p font b i u).freeze

    # Parses a legacy lexicon PHP file, honouring the charset it declares (a handful of
    # the oldest files are genuinely windows-1255) but defaulting to UTF-8 instead of
    # libxml2's Latin-1 when no charset is declared.
    def self.parse_file(path)
      doc = File.open(path) { |f| Nokogiri::HTML(f) }
      return doc unless doc.encoding.blank? || doc.encoding.casecmp?(FALLBACK_ENCODING)

      Nokogiri::HTML(File.read(path, encoding: 'UTF-8'), nil, 'UTF-8')
    end

    # Legacy lexicon PHP files uses font or p elements wrapping anchor with a name as a headers
    def header?(elem, section_name = nil)
      return false unless %w(p font).include?(elem.name)

      if section_name.present?
        # If we're checking for specific section, we look for an anchor with that name
        return elem.at_css("a[name=\"#{section_name}\"]").present?
      else
        # Otherwise we check for an anchor with any name specified
        return elem.at_css('a[name]').present?
      end
    end

    # Some legacy files carry layout-only tables: rows and cells, but nothing to show.
    # Pandoc keeps them as raw HTML, so they survive migration as markup noise.
    def content_free_table?(elem)
      elem.name == 'table' && elem.text.blank? && elem.at_css(VISIBLE_EMPTY_ELEMENTS).nil?
    end

    # The works section header, wherever it sits in the document: the outermost <p>/<font>
    # around the a[name="Books"] anchor, or the bare anchor itself in the handful of files
    # whose wrapper tag was never opened.
    #
    # We search the whole document rather than the heading table's siblings because the
    # legacy files nest the section in every imaginable way: ~400 of them wrap the works and
    # bibliography in a <blockquote> (occasionally two), and a few keep the heading table
    # inside a <p> the works section is not part of. Walking siblings misses all of those and
    # silently turns the entire works block into biography text.
    #
    # Returning the *outermost* wrapper matters: ExtractPersonWorks reads the works lists from
    # the header's following siblings, so the header has to be the element those lists follow.
    def works_header_element(html_doc)
      node = html_doc.at_css(%(a[name="#{WORKS_ANCHOR}"]))
      return nil if node.nil?

      node = node.parent while header_wrapper?(node)
      node
    end

    # Whether +node+'s parent is another wrapper of the same section header, i.e. whether
    # locating the header should climb one level further out.
    #
    # A <span> counts only when +node+ has nothing after it: a <span dir="rtl"> that already
    # holds the works lists as siblings of the header is a section container, not a wrapper,
    # and climbing into it would leave ExtractPersonWorks with no lists to read.
    def header_wrapper?(node)
      parent = node.parent
      return false if parent.nil?
      return true if HEADER_WRAPPERS.include?(parent.name)

      parent.name == 'span' && node.next_element.nil?
    end

    # Elements holding the biography: everything after the heading table, up to the element
    # that carries (or contains) the first section anchor.
    def bio_elements(heading_table)
      elements = []
      elem = next_element_ascending(heading_table)
      while elem.present? && !section_header?(elem)
        elements << elem
        elem = next_element_ascending(elem)
      end
      elements
    end

    # Whether +elem+ is, or wraps, the header of a section (works, bibliography or links).
    def section_header?(elem)
      return true if elem.name == 'a' && SECTION_ANCHORS.include?(elem['name'])

      elem.at_css(SECTION_ANCHOR_SELECTOR).present?
    end

    # The next element in document order that is not a descendant of +elem+: its next sibling,
    # or - once a nesting level is exhausted - the next sibling of the nearest ancestor that has
    # one. Climbing is what lets a bio walk started inside a wrapping <span dir="rtl"> reach the
    # sections that follow the span.
    def next_element_ascending(elem)
      node = elem
      while node.present? && %w(body html).exclude?(node.name)
        sibling = node.next_element
        return sibling if sibling.present?

        node = node.parent
      end

      nil
    end

    def next_element_skipping_blank(elem)
      next_elem = elem.next_element
      while next_elem.present? && next_elem.text.blank? do
        next_elem = next_elem.next_element
      end

      next_elem
    end
  end
end
