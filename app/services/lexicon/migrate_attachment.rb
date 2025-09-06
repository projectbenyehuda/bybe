# frozen_string_literal: true

module Lexicon
  # Service used to migrate attachments referenced on legacy lexicon pages into Ben Yehuda project
  class MigrateAttachment < ApplicationService
    def call(src, lex_entry)
      # removing website prefix if provided (legacy files should use relative paths only but who knows...)
      src = src.gsub(%r{\Ahttp(s)?://benyehuda.org/lexicon/}, '')

      return nil unless src.match?(%r{\A\d+(_|-)files/.*\.(pdf|djvu|jpg|jpeg|gif|png)\z})

      link = LexLegacyLink.find_by(old_path: src)

      if link.nil?
        full_url = 'https://benyehuda.org/lexicon/' + src
        attachments = lex_entry.attachments.attach(io: URI.parse(full_url).open, filename: File.basename(src))
        new_url = Rails.application.routes.url_helpers.url_for(attachments.last)
        link = lex_entry.legacy_links.create(old_path: src, new_path: new_url)
      end

      return link.new_path
    end
  end
end
