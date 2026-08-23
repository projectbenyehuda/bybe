# frozen_string_literal: true

module Lexicon
  # Flags the silent-failure case where a legacy person file has a populated bibliography
  # section, but ExtractCitations returned nothing because it did not recognise that file's
  # layout. Such an entry migrates with no citations, no error and nothing in the queue to
  # signal a problem, so the loss is only noticeable to an editor who opens the entry.
  #
  # Files whose Bib. section holds no contentful <li> at all are *not* flagged: those entries
  # genuinely have nothing to migrate.
  #
  # The flag is recorded on the file's error_message, which the migration queue already shows.
  # We store the I18n key rather than the translated text, because the queue is rendered in the
  # viewing editor's locale while this runs in a background job (see LexiconHelper#lex_file_error).
  class FlagUnmigratedCitations < ApplicationService
    MESSAGE_KEY = 'citations_not_migrated'

    # @param lex_file [LexFile] the migrated file, whose error_message carries the flag
    # @param lex_person [LexPerson] the migrated person
    # @param content [String] the HTML of the source file
    # @return [Boolean] whether the file was flagged
    def call(lex_file, lex_person, content)
      return false if lex_person.citations.any?
      return false unless CountPhpSectionBullets.call(content)[:citations].to_i.positive?
      # Re-running the sweep over an already-flagged file must not pile up duplicate messages.
      return false if lex_file.error_message.to_s.split("\n").include?(MESSAGE_KEY)

      lex_file.log_error(MESSAGE_KEY)
      lex_file.save!
      true
    end
  end
end
