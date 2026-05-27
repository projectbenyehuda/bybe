# frozen_string_literal: true

module Lexicon
  # Job to ingest a LexFile into a Lexicon asynchronously
  class IngestFile
    include Sidekiq::Job

    def perform(lex_file_id)
      Rails.logger.info("Started ingestion of LexFile:#{lex_file_id}")
      lex_file = LexFile.find_by(id: lex_file_id)
      return unless lex_file # protection for a wrong lex_file_id

      Chewy.strategy(:atomic) do
        if lex_file.entrytype_person?
          IngestPerson.call(lex_file)
        elsif lex_file.entrytype_text?
          IngestPublication.call(lex_file)
        else
          raise "unsupported entrytype: #{lex_file.entrytype}"
        end
      end
    rescue StandardError => e
      Rails.logger.warn(e.message)
      Rails.logger.warn(e.backtrace.join("\n"))
      lex_file.log_error(e.message)
      lex_file.save!

      # lex_entry can be in an invalid state here, so we do a direct SQL update of status
      lex_file.lex_entry.update_columns(status: :error)
    ensure
      Rails.logger.info("Finished ingestion of LexFile:#{lex_file_id}")
    end
  end
end
