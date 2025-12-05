# frozen_string_literal: true

module Lexicon
  # Job to ingest a LexFile into a Lexicon asynchronously
  class IngestFile
    include Sidekiq::Job

    def perform(lex_file_id)
      lex_file = LexFile.find(lex_file_id)
      LexEntry.transaction do
        if lex_file.entrytype_person?
          IngestPerson.call(lex_file)
        elsif lex_file.entrytype_text?
          IngestPublication.call(lex_file)
        else
          raise "unsupported entrytype: #{lex_file.entrytype}"
        end
      end
    rescue StandardError => e
      lex_file&.error_message = e.message
      lex_file&.save!
      lex_file&.lex_entry&.status_error!
      # puts e.message
      # puts e.backtrace.join("\n")
    end
  end
end
