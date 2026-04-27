# frozen_string_literal: true

module Lexicon
  # Checks the link for a single LexCitation and updates link_http_status.
  # Enqueued after a citation's link field is changed so that broken-link status
  # is cleared as soon as the editor saves a corrected URL.
  class CheckCitationLinkJob
    include Sidekiq::Job

    def perform(citation_id)
      citation = LexCitation.find(citation_id)

      if citation.link.blank?
        citation.update_column(:link_http_status, nil)
        return
      end

      status = CheckExternalLinks.new.check_url(citation.link)
      citation.update_column(:link_http_status, status)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.warn("Lexicon::CheckCitationLinkJob: citation not found: #{e.message}")
    end
  end
end
