# frozen_string_literal: true

module Lexicon
  # Base class for php file ingestion
  class IngestBase < ApplicationService
    def call(lex_file)
      lex_entry = lex_file.lex_entry

      html_doc = File.open(lex_file.full_path) { |f| Nokogiri::HTML(f) }
      Lexicon::AttachImages.call(html_doc, lex_entry)
      Lexicon::ProcessLinks.call(html_doc, lex_entry)

      lex_entry.lex_item = create_lex_item(html_doc)
      lex_entry.status_draft!

      lex_file.status_ingested!
      lex_entry
    end

    def create_lex_item(_html_doc)
      raise('Not implemented')
    end
  end
end
