# frozen_string_literal: true

module Lexicon
  # Service to parse the works text field from LexPerson into individual LexPublication records
  class ParsePersonWorks
    def initialize(person)
      @person = person
    end

    def call
      return if @person.works.blank?

      # Split works by newlines, each line is a separate publication
      work_lines = @person.works.split("\n").reject(&:blank?)

      work_lines.each do |work_line|
        # Create a LexPublication for each work
        publication = LexPublication.create!(
          description: work_line.strip
        )

        # Link the publication to the person through LexPeopleItem
        @person.lex_people_items.create!(
          item: publication
        )
      end
    end
  end
end
