# frozen_string_literal: true

module Lexicon
  # Utility methods for HTML processing to use them during PHP files parsing
  module HtmlUtils
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

    def next_element_skipping_blank(elem)
      next_elem = elem.next_element
      while next_elem.present? && next_elem.text.blank? do
        next_elem = next_elem.next_element
      end

      next_elem
    end
  end
end
