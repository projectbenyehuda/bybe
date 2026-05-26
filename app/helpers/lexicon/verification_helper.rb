# frozen_string_literal: true

module Lexicon
  # Helper methods for verification workbench views
  module VerificationHelper
    LTR_HEBREW_RATIO_THRESHOLD = 0.2

    # Returns 'ltr' if text has fewer than 20% Hebrew characters, nil otherwise.
    # nil omits the dir attribute in HAML, so the parent RTL context is inherited.
    def text_dir(text)
      return nil if text.blank?

      total = text.length
      hebrew_count = text.each_codepoint.count { |cp| cp.between?(HEB_UTF8_START, HEB_UTF8_END) }
      (hebrew_count.to_f / total) < LTR_HEBREW_RATIO_THRESHOLD ? 'ltr' : nil
    end

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

    # Returns the CSS classes for a work card.
    def work_card_css(work, checklist)
      checklist['works']&.dig('items', work.id.to_s, 'verified') ? 'verified' : 'not-verified'
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
