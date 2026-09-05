# frozen_string_literal: true

module Converters
  # Converts epub file to mobi format using Calibre's ebook_convert utility
  class EpubToMobi < ApplicationService
    # Converts Epub file to Mobi format using Calibre's ebook-convert utility
    def call(epub_filename)
      mobi_filename = epub_filename.gsub(/epub$/, 'mobi')

      unless system('ebook-convert', epub_filename,  mobi_filename)
        raise "ebook-convert failed: #{epub_filename} -> #{mobi_filename}"
      end

      return mobi_filename
    end
  end
end