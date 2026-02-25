# frozen_string_literal: true

module Lexicon
  # Sidekiq job that checks all external links for a given LexEntry.
  # Runs asynchronously after ingestion so that the ingestion job itself
  # is not delayed by per-link network round-trips.
  class CheckExternalLinksJob
    include Sidekiq::Job

    def perform(lex_entry_id)
      lex_entry = LexEntry.includes(:lex_item).find(lex_entry_id)
      CheckExternalLinks.call(lex_entry)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.warn("Lexicon::CheckExternalLinksJob: entry not found: #{e.message}")
    end
  end
end
