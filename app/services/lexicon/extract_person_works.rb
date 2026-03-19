# frozen_string_literal: true

module Lexicon
  # Service to extract works of a Lexicon Person from html document
  class ExtractPersonWorks < ApplicationService
    include HtmlUtils

    WORK_TYPE_HEADERS = {
      'edited' => ['כתיבה, עריכה ושכתוב:', 'עריכה:'],
      'translated' => ['תרגום:']
    }.freeze

    def call(works_header, lex_person)
      next_elem = next_element_skipping_blank(works_header)
      if next_elem.present? && next_elem.name == 'span'
        next_elem = next_elem.first_element_child
      end

      index = 0
      work_type = 'original'
      while next_elem.present? && !header?(next_elem)
        header_line = next_elem.text.strip
        if %w(p font).include?(next_elem.name)
          work_type = WORK_TYPE_HEADERS.keys.detect do |wt|
            WORK_TYPE_HEADERS[wt].include?(header_line)
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

            work = ParsePersonWork.call(li.text)
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
