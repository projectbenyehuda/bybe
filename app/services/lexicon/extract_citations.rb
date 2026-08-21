# frozen_string_literal: true

module Lexicon
  # Service to extract citations from Lexicon entry php file
  class ExtractCitations < ApplicationService
    include HtmlUtils

    def call(html_doc)
      header = header_element(html_doc)
      return [] if header.nil?

      # The next element should be a 'font' tag containing all citations. Sometimes there could be one or more blank
      # paragraphs before it, so we skip blank non-font elements. Font elements are always potential
      # citations-section markers even when their content is empty (e.g. <font color="#FF0000"></font>),
      # so we must not skip them.
      citations_node = header.next_element
      while citations_node.present? && citations_node.name != 'font' && citations_node.text.blank?
        citations_node = citations_node.next_element
      end

      return [] if citations_node&.name != 'font'

      html_nodes = [citations_node]

      # Sometimes we have not a single node with citations, but a node with following li or ul tags.
      # In malformed documents an unclosed <font> wrapper used to nest the whole bibliography, but in
      # well-formed documents each subject is a separate, properly-closed <font> header (e.g.
      # <font color="#FF0000">) sitting as a flat sibling alongside its <ul>. So we walk forward
      # collecting li, ul and any non-header <font> nodes (subject headers, or the legacy size=2
      # list fragments), stopping at the next real section header (e.g. the Links block), which is a
      # <font>/<p> carrying an a[name] anchor.
      if citations_node.at_css('a[name]').blank?
        next_elem = next_element_skipping_blank(citations_node)

        while next_elem && (%w(li ul).include?(next_elem.name) ||
              (next_elem.name == 'font' && !header?(next_elem)))
          html_nodes << next_elem
          next_elem = next_element_skipping_blank(next_elem)
        end
      end

      html = html_nodes.map(&:to_html).join

      # A stray </span> inside a citation <li> can prematurely close the <span> that wraps the
      # citations section. When this happens, Nokogiri displaces all remaining citation content
      # as siblings of the closed <span> rather than keeping it inside the citations node.
      # Collect those displaced siblings to avoid losing citation data.
      if citations_node.at_css('a[name]').blank? && citations_node.parent.name == 'span'
        node = citations_node.parent.next_sibling
        while node
          break if node.element? && (node['name'].present? || node.at_css('a[name]').present?)

          html += node.to_html
          node = node.next_sibling
        end
      end

      # We used to delete parsed nodes earlier, but it turned out in some files citations node contains other
      # sections (e.g. Links block, so we cannot simply remove it)
      # header.remove
      # citations_node.remove
      Lexicon::ParseCitations.call(html)
    end

    private

    def header_element(html_doc)
      header = html_doc.at_css('a[name="Bib."]')

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
