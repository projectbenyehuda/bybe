# frozen_string_literal: true

module Lexicon
  # This service generates single Markdown content from given LexPerson object.
  # This content to be indexed by ElasticSearch.
  class LexPersonContent < ApplicationService
    include BybeUtils

    # Block-level tags whose boundaries are word boundaries. strip_tags drops tags without
    # leaving any whitespace behind, so without this the words on either side of a </td> or
    # a <br> would be fused into a single unsearchable token.
    BLOCK_BOUNDARY_RE = %r{<br\s*/?>|</?\s*(?:p|div|li|ul|ol|tr|td|th|table|h[1-6]|blockquote)\b[^>]*>}i

    def call(lex_person)
      "# #{lex_person.entry.title} - #{lex_person.life_years}\n" \
        "## #{lex_person.aliases}\n\n" \
        "#{bio_text(lex_person)}\n\n" \
        "#{person_works_text(lex_person)}\n\n" \
        "#{citations_text(lex_person)}"
    end

    private

    # The bio is stored as HTML. We index its plain text, so that search-result snippets
    # carry no markup (images in particular) into the results view.
    def bio_text(lex_person)
      return '' if lex_person.bio.blank?

      html2txt(lex_person.bio.gsub(BLOCK_BOUNDARY_RE, "\n"))
    end

    def person_works_text(lex_person)
      lex_person.works.map do |work|
        title = work.lex_publication&.entry&.title || work.title

        result = "#{title} (#{work.publication_place} : #{work.publisher}, #{work.publication_date})"
        if work.comment.present?
          result += " <#{work.comment}>"
        end
        "- #{result}"
      end.join("\n")
    end

    def citations_text(lex_person)
      lex_person.citations.map do |lex_citation|
        author_bit = lex_citation.authors.map(&:display_name).sort.join(', ')
        result = "- #{author_bit}, #{lex_citation.title}, #{lex_citation.from_publication}"
        result += ", עמ #{lex_citation.pages}" if lex_citation.pages.present?
        result
      end.join("\n")
    end
  end
end
