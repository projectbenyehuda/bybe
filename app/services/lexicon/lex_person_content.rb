# frozen_string_literal: true

module Lexicon
  # This service generates single Markdown content from given LexPerson object.
  # This content to be indexed by ElasticSearch.
  class LexPersonContent < ApplicationService
    def call(lex_person)
      "# #{lex_person.entry.title} - #{lex_person.life_years}\n" \
        "## #{lex_person.aliases}\n\n" \
        "#{lex_person.bio}\n\n" \
        "#{person_works_text(lex_person)}\n\n" \
        "#{citations_text(lex_person)}"
    end

    private

    def person_works_text(lex_person)
      lex_person.works.map do |work|
        title = work.lex_publication&.title || work.title

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
