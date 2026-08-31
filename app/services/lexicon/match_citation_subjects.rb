# frozen_string_literal: true

module Lexicon
  # Proposes, for each of a person's legacy citation subject headings, the LexPersonWork that
  # heading names.
  #
  # The legacy PHP bibliographies group the citations about a person under headings, and the
  # migration stored each heading verbatim on every citation below it (LexCitation#subject).
  # A citation still carrying a subject is invisible to the public citations cards, which are
  # driven by LexPersonWork#citations_about — so every heading has to end up either linked to a
  # work or kept as a general sub-heading about the person (LexCitationGroup).
  #
  # The matching itself writes nothing: it returns proposals, which the ingest applies when they
  # are certain and an editor confirms in the verification workbench when they are not. Apply one
  # with Proposal#apply!.
  class MatchCitationSubjects < ApplicationService
    # Headings that bucket citations about the person by kind of writing rather than naming one
    # particular work. These become general sub-headings (LexCitationGroup) keeping their name,
    # instead of being linked to a work.
    #
    # Drawn from a frequency survey of the a[name="Bib."] section of all 4,051 legacy person files:
    # these are every heading that recurs across entries, which is what tells a category apart from
    # a work title (of the ~9,200 distinct headings, the rest are 'על "..."' naming one work each).
    GENERIC_SUBJECTS = [
      'מאמרים', 'ספרים', 'על הספר', 'ביבליוגרפיה', 'ביבליוגרפיות', 'ספרי יובל', 'ספר יובל',
      'ספרי יובל וזכרון', 'מונוגרפיות', 'מאמרים ורשימות', 'מבחר מאמרים מקוונים', 'מבחר שירים מקוונים'
    ].freeze

    # Legacy headings are written with a trailing colon about half the time ('ספרים:' as often as
    # 'ספרים'), which is punctuation of the source layout rather than part of the name.
    def self.normalize_subject(subject)
      subject.to_s.strip.delete_suffix(':').strip
    end

    # Headings read "about X" where the work itself is titled "X" — ParseCitations is supposed to
    # strip this, but the LLM leaves it in often enough that the matcher has to cope with it.
    ABOUT_PREFIX = /\A\s*על\s+/

    # A catalogue title carries a subtitle after " : " that the citation heading does not name
    # ('אור פרא' vs 'אור פרא : שירים'), so both sides are also compared without it.
    SUBTITLE_SEPARATOR = /\s+:\s/

    # A heading about a translation names the work in quotes and then credits the work's own
    # author, whom the catalogue title does not put there: 'על "הכומר מטור" לאונורה דה בלזאק'
    # against 'הכומר מטור / אונורה דה בלזאק'. The credit drags the score below the threshold, so
    # the quoted span is compared on its own as well. Greedy on purpose: a Hebrew title can carry
    # a gershayim of its own ('69.99 ש"ח'), and only the outermost pair delimits the title.
    QUOTED_TITLE = /"(.+)"/

    Proposal = Struct.new(:subject, :citations, :work, :similarity, :generic, :ambiguous,
                          keyword_init: true) do
      # Good enough to apply without an editor looking at it: a heading naming exactly one work,
      # identical once normalized, or one of the recognized general categories.
      def certain?
        generic || (work.present? && similarity == 100)
      end

      # Whether there is anything for an editor to confirm, as opposed to pick by hand.
      def proposed?
        generic || work.present?
      end

      # The name the heading takes as a general sub-heading, i.e. without the layout punctuation.
      def heading_title
        MatchCitationSubjects.normalize_subject(subject)
      end

      # Where the heading stood in the source bibliography. Citations are inserted in source order,
      # so their ids say what their seqno cannot: seqno restarts at 1 under every heading.
      # Applying proposals in this order gives the sub-headings the order they had in the source.
      def source_position
        citations.filter_map(&:id).min || 0
      end

      # Resolves the heading: a general category becomes a sub-heading of the person's general
      # citations, keeping its name; anything else points its citations at the work it names.
      # @return [Integer] how many citations were resolved
      def apply!(person)
        return person.group_citations_with_subject!(subject, heading_title) if generic

        person.link_citations_with_subject!(subject, work)
      end
    end

    # @param person [LexPerson]
    # @return [Array<Proposal>] one per distinct heading still carried by the person's citations,
    #   ordered by heading so the workbench lists them predictably.
    def call(person)
      works = person.works.to_a
      person.citations.where.not(subject: nil).order(:seqno, :id).group_by(&:subject)
            .sort_by { |subject, _| subject }
            .map { |subject, citations| build_proposal(subject, citations, works) }
    end

    private

    def build_proposal(subject, citations, works)
      if GENERIC_SUBJECTS.include?(self.class.normalize_subject(subject))
        return Proposal.new(subject: subject, citations: citations, generic: true)
      end

      scored = works.map { |work| [work, similarity(subject, work)] }
      best_work, best_score = scored.max_by { |_work, score| score }
      return Proposal.new(subject: subject, citations: citations) if best_score.nil? ||
                                                                     best_score < TitleSimilarity::MATCH_THRESHOLD

      # Two works the heading fits equally well are never guessed between: the editor picks.
      ambiguous = scored.many? { |_work, score| score == best_score }
      Proposal.new(subject: subject, citations: citations, work: ambiguous ? nil : best_work,
                   similarity: best_score, ambiguous: ambiguous)
    end

    # The best score over every combination of heading and title, with and without the "about"
    # prefix and the subtitle: the two databases include either at their own discretion.
    def similarity(subject, work)
      subject_variants(subject).product(title_variants(work.title))
                               .map { |a, b| TitleSimilarity.call(a, b) }
                               .max || 0
    end

    # Both with and without the "about" prefix: a work of its own may be titled "על ...", and
    # stripping the prefix there would be stripping part of the title. The quoted span, when the
    # heading has one, is tried as a third reading of the same heading.
    def subject_variants(subject)
      [subject, subject.sub(ABOUT_PREFIX, ''), subject[QUOTED_TITLE, 1]]
        .compact_blank.uniq.flat_map { |variant| title_variants(variant) }.uniq
    end

    def title_variants(title)
      [title, title.split(SUBTITLE_SEPARATOR).first].compact_blank.uniq
    end
  end
end
