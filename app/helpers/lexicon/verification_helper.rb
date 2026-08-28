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

    # Returns the CSS classes for a citation card, including broken-link (or the neutral
    # unverifiable-link, when the check reached no verdict) if needed.
    def citation_card_css(citation, checklist)
      verified = checklist['citations']&.dig('items', citation.id.to_s, 'verified')
      css = verified ? 'verified' : 'not-verified'
      css += ' broken-link' if citation.link_broken?
      css += ' unverifiable-link' if citation.link_unverifiable?
      css
    end

    # The authors of a citation as shown on its verification card. An author already linked to a
    # lexicon entry renders as a link to it; a plaintext author imported from a legacy PHP file
    # renders as text, followed by a button offering to link it whenever a person entry titled
    # exactly like its normalized name exists. `matchable_names` comes from
    # LexCitationAuthor.matchable_names, resolved once for the whole page.
    def citation_authors_for_verification(citation, matchable_names)
      parts = citation.authors.map do |author|
        next link_to(author.display_name, lexicon_entry_path(author.entry)) if author.entry.present?
        next author.display_name unless matchable_names.include?(author.normalized_name&.downcase)

        safe_join([author.display_name, citation_author_match_button(author)], ' ')
      end

      safe_join(parts, ', ')
    end

    # Returns the CSS classes for a link card, including broken-link (or the neutral
    # unverifiable-link, when the check reached no verdict) if needed.
    def link_card_css(link, links_checklist)
      verified = links_checklist&.dig('items', link.id.to_s, 'verified')
      css = verified ? 'verified' : 'not-verified'
      css += ' broken-link' if link.broken?
      css += ' unverifiable-link' if link.unverifiable?
      css
    end

    # Returns the CSS classes for a work card.
    def work_card_css(work, checklist)
      checklist['works']&.dig('items', work.id.to_s, 'verified') ? 'verified' : 'not-verified'
    end

    # Builds the side-by-side word-level diff for the bio comparison modal.
    # Each pane is the full flowing text of one buffer with the words that differ
    # from the other side highlighted inline (see CSS in _bio_comparison).
    # Returns { migrated:, legacy: } of html_safe strings.
    def bio_diff_panes(comparison)
      diff = Diffy::SplitDiff.new(
        comparison.migrated_words.join("\n"),
        comparison.legacy_words.join("\n"),
        format: :html
      )
      {
        migrated: strip_empty_diff_li(diff.left),
        legacy: strip_empty_diff_li(diff.right)
      }
    end

    # Badge text for a broken link. A nil status means the check could not
    # retrieve the URL (dead host, invalid URL, blocked address, redirect loop,
    # etc.); a numeric status is a 4xx/5xx HTTP code.
    def broken_link_badge(status)
      if status.nil?
        t('lexicon.verification.broken_link.inaccessible')
      else
        t('lexicon.verification.broken_link.badge', status: status)
      end
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

    private

    # Opens the match modal for a plaintext citation author, reloading the page on confirmation so
    # the card re-renders the author as a link to the entry it was just matched to.
    def citation_author_match_button(author)
      button_tag t('lexicon.citation_authors.match.title'),
                 type: 'button',
                 class: 'btn btn-sm btn-outline-primary py-0 px-1 match-citation-author',
                 onclick: "openModal('#{match_lexicon_citation_author_path(author)}', function() { reloadPage(); })"
    end

    # Diffy emits a trailing empty <li> when one side has more lines than the
    # other; drop any list item with no visible text so empty rows don't render.
    def strip_empty_diff_li(html)
      frag = Nokogiri::HTML.fragment(html)
      frag.css('li').each { |li| li.remove if li.text.strip.empty? }
      frag.to_html.html_safe
    end
  end
end
