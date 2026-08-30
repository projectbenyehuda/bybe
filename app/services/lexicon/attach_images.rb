# frozen_string_literal: true

module Lexicon
  # Service to migrate all images from html document to ActiveStorage.
  # It removes all processed image tags from html document
  class AttachImages < ApplicationService
    def call(html_doc, lex_entry)
      html_doc.css('img').each do |img|
        src = img['src']

        next if src.blank?

        # Handling for files shared between number of entries
        # They're stored in public/lex folder instead of ActiveStorage
        if src.start_with?('00000_files/')
          img['src'] = src.sub('00000_files/', '/lex/')
          next
        end

        # An image we could not migrate keeps a relative legacy path, which a browser resolves
        # against whatever page it is rendered on; send it back to the old site instead.
        img['src'] = MigrateAttachment.call(src, lex_entry).presence || ProcessLinks.absolutize(src)
      end
    end
  end
end
