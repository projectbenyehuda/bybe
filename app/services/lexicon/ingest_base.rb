# frozen_string_literal: true

module Lexicon
  # Base class for php file ingestion
  class IngestBase < ApplicationService
    def call(lex_file)
      if lex_file.lex_entry.present?
        # removing existing lex entry to create new one
        lex_file.lex_entry.destroy!
      end

      lex_entry = LexEntry.create!(
        title: lex_file.title,
        status: :raw,
        legacy_filename: lex_file.fname
      )

      html_doc = File.open(lex_file.full_path) { |f| Nokogiri::HTML(f) }
      Lexicon::AttachImages.call(html_doc, lex_entry)
      Lexicon::ProcessLinks.call(html_doc, lex_entry)

      lex_entry.lex_item = create_lex_item(html_doc)
      lex_entry.save!

      lex_file.lex_entry = lex_entry
      lex_file.status_ingested!

      lex_entry
    end

    def create_lex_item(_html_doc)
      raise('Not implemented')
    end
  end
end
