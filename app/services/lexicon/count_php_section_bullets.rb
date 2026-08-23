# frozen_string_literal: true

module Lexicon
  # Counts the <li> items in each section of a legacy PHP file. Sections are delimited by the
  # named anchors Books, Bib. and links. Empty (whitespace-only) list items are excluded, to
  # match what migration itself keeps.
  #
  # Returns a hash with :works, :citations and :links counts. A section's count is nil when its
  # anchor is missing from the document, which is what lets callers tell "no such section" apart
  # from "section present but empty".
  class CountPhpSectionBullets < ApplicationService
    def call(content)
      return { works: nil, citations: nil, links: nil } if content.blank?

      books_pos = content.index(/name\s*=\s*["']Books["']/i)
      bib_pos = content.index(/name\s*=\s*["']Bib\.["']/i)
      links_pos = content.index(/name\s*=\s*["']links["']/i)

      works_count = nil
      citations_count = nil
      links_count = nil

      if books_pos
        works_end = bib_pos || links_pos || content.length
        works_count = count_nonempty_li(content[books_pos...works_end])
      end

      if bib_pos
        citations_end = links_pos || content.length
        citations_count = count_nonempty_li(content[bib_pos...citations_end])
      end

      links_count = count_nonempty_li(content[links_pos..]) if links_pos

      { works: works_count, citations: citations_count, links: links_count }
    end

    private

    def count_nonempty_li(html_fragment)
      Nokogiri::HTML.fragment(html_fragment).css('li').count { |li| li.text.strip.present? }
    end
  end
end
