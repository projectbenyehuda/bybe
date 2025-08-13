# frozen_string_literal: true

module Lexicon
  # Class used to ingest publications from the old lexicon
  class IngestPublication < ApplicationService
    def call(file_id)
      file = LexFile.find(file_id)

      lex_entry = LexEntry.new(
        title: file.title,
        status: :raw
      )

      pub = create_lex_publication(lex_entry, file)
      lex_entry.lex_item = pub
      lex_entry.save!

      file.lex_entry = lex_entry
      file.status_ingested!

      lex_entry
    end

    private

    def create_lex_publication(lex_entry, file)
      return lex_entry.lex_item if lex_entry.lex_item.present?

      html_doc = File.open(file.full_path) { |f| Nokogiri::HTML(f) }

      description = HtmlToMarkdown.call(html_doc.at_css('.margin').text)

      toc_node = html_doc.at_css('blockquote')
      toc_node.at_css('font[size="4"][color="#0000FF"]')&.remove # removing TOC heading

      LexPublication.new(
        description: HtmlToMarkdown.call(description),
        toc: HtmlToMarkdown.call(toc_node.text),
        az_navbar: true # defaulting to true for all records
      )
    end
  end
end
