# frozen_string_literal: true

module Lexicon
  # Service used to migrate attachments referenced on legacy lexicon pages into Ben Yehuda project
  class MigrateAttachment < ApplicationService
    LEXICON_FILES_REGEX = %r{\A(?<file_id>\d+)(_|-)files/.*\.(pdf|djvu|jpg|jpeg|gif|png)(#(?<anchor>.*))?\z}

    def call(src, lex_entry)
      # removing website prefix if provided (legacy files should use relative paths only but who knows...)
      src = src.gsub(%r{\Ahttp(s)?://#{Lexicon::OLD_LEXICON_PATH}/}, '')

      match = src.match(LEXICON_FILES_REGEX)
      return nil unless match

      # Some links may contain optional anchor to specific part of the document
      anchor = match['anchor']
      if anchor.present?
        # If anchor present we remove it from the URL
        src = src.delete_suffix("##{anchor}")
      end

      # Sometime URI comes only partially escaped (escaped whitespaces, but not escaped Hebrew characters)
      # So we unescape whole URI before processing to get fancy filename from it
      src = URI::DEFAULT_PARSER.unescape(src)

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

        full_url = "#{Lexicon::OLD_LEXICON_URL}/#{src}"
        filename = File.basename(File.basename(src))

        # We know URL should not contain escaped characters at this point so we can safely escape whole URL
        uri = URI.parse(URI::DEFAULT_PARSER.escape(full_url))

        file_entry.attachments.attach(io: uri.open, filename: filename)
        new_path = file_entry.download_path(filename)
        link = file_entry.legacy_links.create(old_path: src, new_path: new_path)
      end

      if anchor.blank?
        return link.new_path
      else
        return "#{link.new_path}##{anchor}"
      end
    rescue OpenURI::HTTPError => e
      lex_entry.lex_file.log_error("Failed to download file: #{src}, error: #{e.message}")
      return nil # If we failed to migrate attachment we return nil, so link will be left as-is
    end
  end
end
