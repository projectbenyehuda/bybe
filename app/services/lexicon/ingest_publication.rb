# frozen_string_literal: true

module Lexicon
  # Class used to ingest publications from the old lexicon
  class IngestPublication < IngestBase
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

      publication = LexPublication.create(
        description: description,
        toc: toc,
        az_navbar: true # defaulting to true for all records
      )

      parse_links(publication, links_section_html(html_doc.to_html))
      publication.save!

      publication
    end

    TOC_HEADERS = ['תוכן העניינים'].freeze

    private

    # If we have a blockquote wrapping the part of the content, we want to remove it and keep the content inside it.
    def flatten_blockquote(html_doc)
      # I believe initial intention was to wrap TOC, but in some files whole content is wrapped, or only part of TOC
      # is wrapped, so we just remove the first blockquote we find and keep the content inside it to simplify parsing.
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

      # TOC header can we wrapped into a paragraph
      header_node = header_node.parent if header_node&.parent&.name == 'p'
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
        elsif elem.name == 'font' && elem['color'] == '#0000FF' && elem.text.include?('קישורים')
          # We assume TOC is ended when we encounter a links section
          break
        elsif elem.name == 'table'
          elem.css('tr').each do |tr|
            result << '- ' << tr.css('td').map { |td| HtmlToMarkdown.call(td.inner_html) }.join(' ') << "\n"
          end
        elsif elem.text.present? # we skip empty html elements
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
