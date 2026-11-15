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

    # Longest header that can still be a sub-heading. Anything longer in header markup is a work
    # line the file wrapped in <font> by mistake, or a remark.
    MAX_SUB_HEADING_LENGTH = 80

    # Footer some files carry inside the works section ('עודכן לאחרונה: 25 באפריל 2017').
    LAST_UPDATED_PREFIX = 'עודכן לאחרונה'

    # A work line's publication details: '(place : publisher, year)'.
    PUBLICATION_DETAILS_RE = /\(.*:.*,.*\)/

    def call(works_header, lex_person)
      @lex_person = lex_person
      node = works_header.next_sibling
      if next_element_skipping_blank(works_header).nil?
        # Works may be embedded inside a span within the works header element itself
        # (e.g. when a <span dir="rtl"> wrapping the whole page is parsed as a child of the <p>)
        node = works_header.at_css('> span')&.children&.first
      end

      @index = 0
      @work_type = 'original'
      # A sub-heading becomes a LexPersonWorkGroup only once a work turns up under it: legacy files
      # also put remarks and stray fragments in header markup, and a heading with nothing under it
      # is one of those.
      @pending_group_title = nil
      @group = nil
      # Nodes rather than elements: 00421.php writes its sub-headings ('שירה ופרוזה:', 'עיון:') as
      # bare text between the lists, and walking elements alone silently drops them.
      # Not node.present?: Nokogiri::XML::Node#blank? is true for a whitespace-only text node.
      until node.nil?
        if node.element? && node.text.present?
          break if works_section_end?(node)

          # Legacy files re-open a <span dir="rtl"> before each work type and never close it, so
          # Nokogiri nests the list that follows inside it. Step in rather than walking past it,
          # which would drop every work of that type (00104.php's translations).
          if node.name == 'span'
            node = node.children.first
            next
          end

          process_element(node)
        elsif node.text?
          process_text(node)
        end
        node = node.next_sibling
      end

      node
    end

    private

    def process_element(elem)
      if %w(p font).include?(elem.name)
        process_header(elem.text)
      elsif elem.name == 'ul'
        elem.css('li').each do |li|
          # sometimes list can contains empty items
          next if li.text.blank? || li.text.strip.empty?

          add_work(ParsePersonWork.call(li))
        end
      else
        Rails.logger.warn('Unexpected element while parsing person works: ' + elem.name)
      end
    end

    # Bare text is a sub-heading only when it reads like one, colon and all. Otherwise it is a
    # fragment of a list item the markup broke apart (00424.php), not worth a heading.
    def process_text(text_node)
      line = text_node.text.squish
      process_header(line) if line.end_with?(':')
    end

    # squish, not strip: legacy files hard-wrap a header across two source lines
    # ("ספרים \r\nבתרגומו:" in 01741.php), and the embedded newline hides it from
    # WORK_TYPE_HEADERS, filing the whole section as original works.
    def process_header(text)
      header_line = text.squish
      work_type = work_type_of(header_line)
      if work_type.present?
        start_section(work_type)
      elsif sub_heading?(header_line)
        # An unrecognized header opens a sub-heading of the original works, rather than of the
        # section it appears in: across the legacy files, most such headers that follow a
        # translations or editing section open a section of original works the list above does not
        # recognize (מבחר ממאמריו, ביבליוגרפיה, ...), not a subdivision of it. An editor moves a
        # sub-heading that does subdivide another section there in one step.
        start_section('original')
        @pending_group_title = header_line.delete_suffix(':').strip
      else
        Rails.logger.warn("Unrecognized works section header: #{header_line}")
      end
    end

    # The work type a header opens, or nil if it is not one of WORK_TYPE_HEADERS. A header
    # matching a listed one but for a bracketed modifier ('עריכה (מבחר):', 'עריכה: [מבחר]') or its
    # colon still counts -- fragmented headers (<font>עריכה</font><font>(מבחר)</font><font>:</font>)
    # lose both to the elements that follow.
    def work_type_of(header_line)
      core = header_core(header_line)
      WORK_TYPE_HEADERS.keys.detect do |wt|
        WORK_TYPE_HEADERS[wt].any? do |h|
          header_line.start_with?(h) || header_core(h) == core
        end
      end
    end

    # Whether an unrecognized header names a sub-heading, rather than being header-styled debris:
    # a modifier of the header before it ('(מבחר)', '<מבחר>', ':'), a fragment of an angle-bracketed
    # comment ('<', 'הרשימה באדיבות יעל שכנאי>'), a last-updated footer, or a work line.
    def sub_heading?(header_line)
      return false unless header_core(header_line).match?(/\p{L}/)
      return false if header_line.count('<') != header_line.count('>')
      return false if header_line.length > MAX_SUB_HEADING_LENGTH
      return false if header_line.start_with?(LAST_UPDATED_PREFIX)

      !header_line.match?(PUBLICATION_DETAILS_RE)
    end

    # A header with its bracketed modifiers and trailing colon removed: 'עריכה (מבחר):' -> 'עריכה'.
    def header_core(header_line)
      header_line.gsub(/\([^)]*\)|\[[^\]]*\]|<[^>]*>/, ' ').squish.delete_suffix(':').strip
    end

    def start_section(work_type)
      @work_type = work_type
      @pending_group_title = nil
      @group = nil
      @index = @lex_person.works.select { |w| w.work_type == work_type }.map(&:seqno).max || 0
    end

    def add_work(work)
      if @pending_group_title.present?
        @group = find_or_build_group(@pending_group_title)
        @pending_group_title = nil
      end

      work.work_type = @work_type
      work.work_group = @group
      work.seqno = @index += 1
      @lex_person.works << work
    end

    # A file repeating a sub-heading within one section gets one group, not two of the same name.
    def find_or_build_group(title)
      @lex_person.work_groups.detect { |g| g.work_type == @work_type && g.title == title } ||
        @lex_person.work_groups.build(title: title, work_type: @work_type)
    end
  end
end
