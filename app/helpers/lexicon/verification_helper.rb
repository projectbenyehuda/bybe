# frozen_string_literal: true

module Lexicon
  # Helper methods for verification workbench views
  module VerificationHelper
    # Returns the CSS classes for a citation card, including broken-link if needed.
    def citation_card_css(citation, checklist)
      verified = checklist['citations']&.dig('items', citation.id.to_s, 'verified')
      css = verified ? 'verified' : 'not-verified'
      css += ' broken-link' if citation.link_broken?
      css
    end

    # Returns the CSS classes for a link card, including broken-link if needed.
    def link_card_css(link, links_checklist)
      verified = links_checklist&.dig('items', link.id.to_s, 'verified')
      css = verified ? 'verified' : 'not-verified'
      css += ' broken-link' if link.broken?
      css
    end

    def badge_class_for_status(status)
      case status.to_sym
      when :draft then 'bg-secondary'
      when :verifying then 'bg-warning text-dark'
      when :verified then 'bg-success'
      when :error then 'bg-danger'
      when :published then 'bg-primary'
      else 'bg-light text-dark'
      end
    end
  end
end
