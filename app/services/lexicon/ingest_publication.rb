# frozen_string_literal: true

module Lexicon
  # Class used to ingest publications from the old lexicon
  class IngestPublication < IngestBase
    def create_lex_item(html_doc)
      description = html_doc.css('p.margin')
                            .map { |tag| HtmlToMarkdown.call(tag.inner_html) }
                            .join("\n\n")

      LexPublication.create(
        description: description,
        toc: parse_toc(html_doc),
        az_navbar: true # defaulting to true for all records
      )
    end

    private

    def parse_toc(html_doc)
      toc_node = html_doc.at_css('blockquote')

      return '' if toc_node.nil?

      toc_node.at_css('font[color="#0000FF"]')&.remove # removing TOC heading

      table = toc_node.at_css('table')

      if table.present?
        result = +''
        table.css('tr').each do |tr|
          result << tr.css('td').map { |td| HtmlToMarkdown.call(td.inner_html) }.join(' ') << "\n"
        end
        result
      else
        HtmlToMarkdown.call(toc_node.inner_html)
      end
    end
  end
end
