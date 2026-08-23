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

    def next_element_skipping_blank(elem)
      next_elem = elem.next_element
      while next_elem.present? && next_elem.text.blank? do
        next_elem = next_elem.next_element
      end

      next_elem
    end
  end
end
