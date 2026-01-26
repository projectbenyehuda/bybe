# frozen_string_literal: true

module Lexicon
  # Service used to migrate attachments referenced on legacy lexicon pages into Ben Yehuda project
  class MigrateAttachment < ApplicationService
    LEXICON_FILES_REGEX = %r{\A(?<file_id>\d+)(_|-)files/.*\.(pdf|djvu|jpg|jpeg|gif|png)\z}.freeze

    def call(src, lex_entry)
      # removing website prefix if provided (legacy files should use relative paths only but who knows...)
      src = src.gsub(%r{\Ahttp(s)?://benyehuda.org/lexicon/}, '')

      match = src.match(LEXICON_FILES_REGEX)
      return nil unless match

      link = LexLegacyLink.find_by(old_path: src)

      if link.nil?
        # Sometimes pages of publications uses images from people page, and vice versa.
        # So we try to attach file to the same entry as it was attached in the legacy system
        # Taking legacy filename from the src path
        filename = "#{match[:file_id]}.php"
        begin
          file = LexFile.find_by!(fname: filename)
          file_entry = file.lex_entry
        rescue ActiveRecord::RecordNotFound
          # if not found using the provided lex_entry
          file_entry = lex_entry
        end

        full_url = 'https://benyehuda.org/lexicon/' + src
        filename = File.basename(src)
        file_entry.attachments.attach(io: URI.parse(full_url).open, filename: filename)
        new_path = file_entry.download_path(filename)
        link = file_entry.legacy_links.create(old_path: src, new_path: new_path)
      end

      return link.new_path
    rescue OpenURI::HTTPError => e
      raise "Failed to download file: #{src}, error: #{e.message}"
    end
  end
end
