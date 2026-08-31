# frozen_string_literal: true

module Lexicon
  # Recovers the general sub-headings (ספרים, מאמרים, ספרי יובל, ...) of an already-migrated
  # person's bibliography from their legacy PHP file.
  #
  # Until LexCitationGroup existed the migration threw those headings away: a heading recognized as
  # a general category had its citations cleared (LexPerson#link_citations_with_subject! with no
  # work), conflating every group into one flat general list. This re-reads the source, works out
  # which heading each general citation sat under, and puts it back.
  #
  # Only the citations that are general *and* ungrouped are touched, so it is safe to re-run and
  # never disturbs an editor's decisions: a citation linked to a work, already under a sub-heading,
  # or still carrying an unresolved subject is left exactly as it is.
  class RecoverCitationHeadings < ApplicationService
    # Why a person was passed over, for the caller's report.
    Result = Struct.new(:person_id, :skipped, :groups, :grouped_count, :unmatched_count,
                        keyword_init: true) do
      def skipped?
        skipped.present?
      end
    end

    # Shorter than this a title matches too much of the source text to be trusted; the same floor
    # ParseCitations uses when it joins parsed citations back to the <li> they came from.
    MIN_MATCHABLE_TITLE = 8

    # @param person [LexPerson]
    # @return [Result]
    def call(person)
      @person = person
      path = person.entry&.lex_file&.full_path
      return Result.new(person_id: person.id, skipped: :no_legacy_file) if path.blank? || !File.exist?(path)

      items = source_items(path)
      return Result.new(person_id: person.id, skipped: :no_headings_in_source) if items.empty?

      assign(items)
    end

    private

    # The <li> elements of the legacy bibliography that sit under a recoverable general
    # sub-heading, in source order, each with the heading it belongs to.
    def source_items(path)
      html = Lexicon::ExtractCitations.new.section_html(HtmlUtils.parse_file(path))
      return [] if html.blank?

      heading = nil
      Nokogiri::HTML::DocumentFragment.parse(html).css('*').filter_map do |node|
        next if node.ancestors('li').any? # content of a citation, never a heading of its own

        if node.name == 'li'
          next if heading.nil?

          { heading: heading, text: normalize(own_text(node)) }
        elsif %w(font b p).include?(node.name) && node.css('ul, li').empty?
          heading = general_heading(node.text)
          nil
        end
      end
    end

    # The general sub-heading a source header stands for, or nil for anything else.
    #
    # Only the recognized general categories are recovered, deliberately. Legacy markup is broken
    # enough that walking it turns up plenty of headers that are not general sub-headings at all --
    # work titles both bare and quoted ('אבני גדר', 'On "Exile from exile"'), the links section's
    # own 'קישורים' header bleeding in through an unclosed tag, and outright debris ('V–XXIV').
    # Inventing a sub-heading out of any of those would be worse than the flat list we have, and an
    # editor can always add one by hand in the citations tab.
    def general_heading(text)
      title = Lexicon::MatchCitationSubjects.normalize_subject(text.squish)
      Lexicon::MatchCitationSubjects::GENERIC_SUBJECTS.include?(title) ? title : nil
    end

    # Matches each source <li> to the general citation it was migrated into, and files that citation
    # under the <li>'s heading. Matching is by title containment, longest title first and each
    # citation claimed at most once -- the same join ParseCitations falls back to.
    def assign(items)
      ungrouped = @person.citations.where(lex_person_work_id: nil, lex_citation_group_id: nil, subject: nil)
                         .order(:seqno, :id).to_a
      candidates = ungrouped.select { |c| normalize(c.title).length >= MIN_MATCHABLE_TITLE }
      claimed = {}

      items.each do |item|
        citation = candidates.reject { |c| claimed.key?(c.id) }
                             .select { |c| item[:text].include?(normalize(c.title)) }
                             .max_by { |c| normalize(c.title).length }
        claimed[citation.id] = item[:heading] if citation
      end

      persist(ungrouped, claimed)
    end

    # Writes the recovered grouping, renumbering the seqno of every list it touches -- a citation's
    # seqno is its position within its own heading, so moving citations out of the general list
    # would otherwise leave both lists numbered from a sequence they no longer follow.
    def persist(ungrouped, claimed)
      groups = {}
      ActiveRecord::Base.transaction do
        claimed.values.uniq.each do |title|
          groups[title] = @person.citation_groups.find_or_create_by!(title: title)
        end

        ungrouped.group_by { |citation| claimed[citation.id] }.each do |title, citations|
          citations.each_with_index do |citation, index|
            citation.update!(citation_group: groups[title], seqno: index + 1)
          end
        end
      end

      Result.new(person_id: @person.id, groups: groups.keys, grouped_count: claimed.size,
                 unmatched_count: ungrouped.size - claimed.size)
    end

    # Text of an <li> without the text of any citation nested inside it, so that a nested
    # citation's title cannot be matched against its containing one.
    def own_text(list_item)
      copy = list_item.dup
      copy.css('li').each(&:remove)
      copy.text
    end

    # [[:space:]] rather than \s: legacy markup is littered with &nbsp;, and Ruby's \s does not
    # match U+00A0, so a title would fail to be found inside the very <li> it was parsed from.
    def normalize(text)
      text.to_s.gsub(/[[:punct:]]/, ' ').gsub(/[[:space:]]+/, ' ').strip
    end
  end
end
