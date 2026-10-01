# frozen_string_literal: true

module Lexicon
  # Class used to ingest publications from the old lexicon
  class IngestPublication < IngestBase
    include HtmlUtils

    def create_lex_item(html_doc)
      flatten_blockquote(html_doc)

      toc = parse_toc(html_doc)

      description = +''
      html_doc.css('p.margin').each do |tag|
        str = HtmlToMarkdown.call(tag.inner_html)
        tag.remove
        description.presence&.<<("\n\n")
        description << str
      end

      LexPublication.create(
        description: description,
        toc: toc,
        az_navbar: true # defaulting to true for all records
      )
    end

    TOC_HEADERS = ['תוכן העניינים']

    private

    def flatten_blockquote(html_doc)
      blockquote = html_doc.at_css('blockquote')
      return if blockquote.nil?

      content = blockquote.children
      blockquote.replace(content)
    end

    def toc_header(html_doc)
      header_node = nil

      html_doc.css('font[color="#0000FF"]').each do |node|

        if TOC_HEADERS.any? { |heading| node.text.include?(heading) }
          header_node = node
          break
        end
      end

      if header_node.present?
        # TOC header can we wrapped into a paragraph
        if header_node.parent.name == 'p'
          header_node = header_node.parent
        end
      end

      header_node
    end

    def parse_toc(html_doc)
      header = toc_header(html_doc)
      return nil if header.nil?

      elem = next_element_skipping_blank(header)
      header.remove

      result = +''

      while elem.present?
        # Sometimes TOC can be present as table, in this case we convert table to list
        if elem.name == 'form'
          # We assume TOC is ended with a form rendering back button
          break
        elsif elem.name == 'table'
          elem.css('tr').each do |tr|
            result << '- ' << tr.css('td').map { |td|  HtmlToMarkdown.call(td.inner_html) }.join(' ') << "\n"
          end
        else
          result << HtmlToMarkdown.call(elem.inner_html) << "\n"
        end

        next_elem = next_element_skipping_blank(elem)
        elem.remove
        elem = next_elem
      end

      result
    end
  end
end
