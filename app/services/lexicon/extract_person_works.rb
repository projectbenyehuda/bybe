# frozen_string_literal: true

module Lexicon
  # Service to extract works of a Lexicon Person from html document
  class ExtractPersonWorks < ApplicationService
    include HtmlUtils

    WORK_TYPE_HEADERS = {
      'edited' => ['כתיבה, עריכה ושכתוב:', 'עריכה:', 'עריכה: (מבחר)'],
      # 'תרגומים לשפות זרות:' and its kin are deliberately absent — those sections list
      # translations *of* the person's works, which stay 'original'.
      'translated' => ['תרגום:', 'תרגומים:', 'תרגומיו:', 'תרגומיה:',
                       'ספרים בתרגומו:', 'ספרים בתרגומה:'],
      'festschrift' => ['ספר זכרון:', 'ספרי יובל', 'ספרי יובל:',
                        'ספרי יובל וזכרון', 'ספרי יובל וזכרון:', 'ספרי יובל וזיכרון:']
    }.freeze

    def call(works_header, lex_person)
      next_elem = next_element_skipping_blank(works_header)
      if next_elem.present? && next_elem.name == 'span'
        next_elem = next_elem.first_element_child
      elsif next_elem.nil?
        # Works may be embedded inside a span within the works header element itself
        # (e.g. when a <span dir="rtl"> wrapping the whole page is parsed as a child of the <p>)
        inner_span = works_header.at_css('> span')
        next_elem = inner_span&.first_element_child
      end

      index = 0
      work_type = 'original'
      while next_elem.present? && !works_section_end?(next_elem)
        # Legacy files re-open a <span dir="rtl"> before each work type and never close it, so
        # Nokogiri nests the list that follows inside it. Step in rather than walking past it,
        # which would drop every work of that type (00104.php's translations).
        if next_elem.name == 'span'
          next_elem = next_elem.first_element_child
          next
        end

        # squish, not strip: legacy files hard-wrap a header across two source lines
        # ("ספרים \r\nבתרגומו:" in 01741.php), and the embedded newline hides it from
        # WORK_TYPE_HEADERS, filing the whole section as original works.
        header_line = next_elem.text.squish
        if %w(p font).include?(next_elem.name)
          work_type = WORK_TYPE_HEADERS.keys.detect do |wt|
            WORK_TYPE_HEADERS[wt].include?(header_line) ||
              WORK_TYPE_HEADERS[wt].any? { |h| header_line.start_with?(h) }
          end

          if work_type.nil?
            Rails.logger.warn("Unrecognized works section header: #{header_line}")
            work_type = 'original' # defaulting to original if we don't recognize the header
          end
          index = lex_person.works.select { |w| w.work_type == work_type }.map(&:seqno).max || 0
        elsif next_elem.name == 'ul'
          next_elem.css('li').each do |li|
            # sometimes list can contains empty items
            next if li.text.blank? || li.text.strip.empty?

            work = ParsePersonWork.call(li)
            work.work_type = work_type
            work.seqno = index += 1
            lex_person.works << work
          end
        else
          Rails.logger.warn('Unexpected element while parsing person works: ' + next_elem.name)
        end
        next_elem = next_element_skipping_blank(next_elem)
      end

      next_elem
    end
  end
end
