# frozen_string_literal: true

module Lexicon
  # Service used to migrate attachments referenced on legacy lexicon pages into Ben Yehuda project
  class MigrateAttachment < ApplicationService
    def call(src, lex_entry)
      # removing website prefix if provided (legacy files should use relative paths only but who knows...)
      src = src.gsub(%r{\Ahttp(s)?://benyehuda.org/lexicon/}, '')

      # TODO: we should attach file to proper lex entry, based on folder name
      return nil unless src.match?(%r{\A\d+(_|-)files/.*\.(pdf|djvu|jpg|jpeg|gif|png)\z})

      link = LexLegacyLink.find_by(old_path: src)

      if link.nil?
        full_url = 'https://benyehuda.org/lexicon/' + src
        attachments = lex_entry.attachments.attach(io: URI.parse(full_url).open, filename: File.basename(src))
        new_path = Rails.application.routes.url_helpers.rails_blob_path(attachments.last, only_path: true)
        link = lex_entry.legacy_links.create(old_path: src, new_path: new_path)
      end

      return link.new_path
    rescue OpenURI::HTTPError => e
      raise "Failed to download file: #{src}, error: #{e.message}"
    end
  end
end
