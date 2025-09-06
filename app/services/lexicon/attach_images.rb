# frozen_string_literal: true

module Lexicon
  # Service to migrate all images from html document to ActiveStorage.
  # It removes all processed image tags from html document
  class AttachImages < ApplicationService
    def call(html_doc, lex_entry)
      html_doc.css('img').each do |img|
        src = img['src']
        new_src = MigrateAttachment.call(src, lex_entry)
        if new_src.present?
          img['src'] = new_src
        end
      end
    end
  end
end
