# frozen_string_literal: true

module Lexicon
  # Class used to ingest publications from the old lexicon
  class IngestPublication < ApplicationService
    def call(file_id)
      file = LexFile.find(file_id)

      lex_entry = LexEntry.create(
        title: file.title,
        status: :raw
      )

      html_doc = File.open(file.full_path) { |f| Nokogiri::HTML(f) }
      AttachImages.call(html_doc, lex_entry)

      pub = create_lex_publication(lex_entry, html_doc)
      lex_entry.lex_item = pub
      lex_entry.save!

      file.lex_entry = lex_entry
      file.status_ingested!

      lex_entry
    end

    private

    def create_lex_publication(lex_entry, html_doc)
      return lex_entry.lex_item if lex_entry.lex_item.present?

      description = html_doc.css('p.margin')
                            .map { |tag| HtmlToMarkdown.call(tag.inner_html) }
                            .join("\n\n")

      LexPublication.create(
        description: description,
        toc: parse_toc(html_doc),
        az_navbar: true # defaulting to true for all records
      )
    end

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
