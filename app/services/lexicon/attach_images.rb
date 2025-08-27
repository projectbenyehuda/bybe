# frozen_string_literal: true

module Lexicon
  # Service to migrate all images from html document to ActiveStorage.
  # It removes all processed image tags from html document
  class AttachImages < ApplicationService
    def call(html_doc, lex_entry)
      html_doc.css('img').each do |img|
        src = img['src']
        if src.match?(%r{\A\d+(_|-)files/.+\.(jpg|jpeg|png|gif)\z})
          src = 'https://benyehuda.org/lexicon/' + src
        end
        begin
          lex_entry.images.attach(io: URI.parse(src).open, filename: File.basename(src))
        rescue StandardError
          Rails.logger.error("Failed to attach image #{src}")
        end
        img.remove # removing img tag from html
      end
    end
  end
end
