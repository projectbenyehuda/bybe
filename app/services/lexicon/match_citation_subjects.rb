# frozen_string_literal: true

module Lexicon
  # Proposes, for each of a person's legacy citation subject headings, the LexPersonWork that
  # heading names.
  #
  # The legacy PHP bibliographies group the citations about a person under headings, and the
  # migration stored each heading verbatim on every citation below it (LexCitation#subject).
  # A citation still carrying a subject is invisible to the public citations cards, which are
  # driven by LexPersonWork#citations_about — so every heading has to end up either linked to a
  # work or cleared as a general heading about the person.
  #
  # Nothing here writes: it returns proposals, which the ingest auto-links when they are certain
  # and an editor confirms in the verification workbench when they are not. Use
  # LexPerson#link_citations_with_subject! to apply one.
  class MatchCitationSubjects < ApplicationService
    # Headings that bucket citations about the person rather than about one particular work.
    # These are cleared without a work, leaving their citations as general citations.
    GENERIC_SUBJECTS = ['מאמרים', 'ספרים', 'על הספר'].freeze

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
      # Good enough to apply without an editor looking at it: one work, identical once normalized.
      def certain?
        work.present? && similarity == 100
      end

      # Whether there is anything for an editor to confirm, as opposed to pick by hand.
      def proposed?
        generic || work.present?
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
      if GENERIC_SUBJECTS.include?(subject.strip)
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
