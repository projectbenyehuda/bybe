# frozen_string_literal: true

module Lexicon
  # Service to parse works of Lexicon Person
  class ParsePersonWork < ApplicationService
    ABOUT_PREFIX = 'על'
    COLLABORATOR_PREFIX = 'בשיתוף'

    ROLE_STRINGS = {
      illustrator: ['איורים'],
      editor: ['עריכה']
    }.freeze


    # @param element [Nokogiri::XML::Element] element containing the work information, typically a list item
    def call(element)
      line = element.text&.squish
      line = line.strip
      result = LexPersonWork.new

      # Extract comments if exists. Comments are wrapped in < > brackets and can contain info about co-authors
      comments = line.scan(/<[^>]+>/)
      if comments.present?
        # removing wrapping angle brackets ('<comment>' -> 'comment')
        comments.map! { |comment| comment[1..-2] }

        process_comments(comments, result, element)

        # removing all comments from the line
        line = line.gsub(/<[^>]+>/, '').squish
      end

      # Find the last opening parenthesis (to handle colons in title)
      last_open_paren = line.rindex('(')
      last_close_paren = line.rindex(')')

      if !last_open_paren || !last_close_paren || last_open_paren >= last_close_paren
        # no valid parenthesis found, return title only
        result.title = line
        return result
      end

      # Extract title (everything before last '(')
      result.title = line[0...last_open_paren].strip

      # Extract inner content
      inner = line[(last_open_paren + 1)...last_close_paren].strip

      # Parse inner content: "place : publisher, year"
      match = inner.match(/(?<place>[^:]+?)\s*:\s*(?<publisher>.+?),\s*(?<year>.+)/)
      if match
        result.publication_place = match[:place].strip
        result.publisher = match[:publisher].strip
        result.publication_date = match[:year].strip
      end

      result
    end

    private

    def process_comments(comments, person_work, element)
      # removing comments representing coauthors

      plain_comments = []

      comments.each do |comment_line|
        # sometimes comment can contain several coauthor records separated by ';'
        parts = comment_line.split(';')

        parts.each do |comment|
          # At first checking if this is a coauthor comment
          linked_person = process_coauthor_comment(comment)

          # Otherwise checking if this comment points to person about whom given work is
          linked_person = process_prefix_comment(comment, ABOUT_PREFIX, :about) if linked_person.nil?
          # Otherwise checking if this is a collaboration comment
          linked_person = process_prefix_comment(comment, COLLABORATOR_PREFIX, :collaborator) if linked_person.nil?

          if linked_person.present?
            link_person_to_lex_entry(linked_person, element)
            person_work.linked_people << linked_person
          else
            plain_comments << comment
          end
        end
      end

      # All non-coauthor comments are stored as lines in coauthor comment field, separated by line breaks
      person_work.comment = plain_comments.join("\n")
    end

    # Coauthor comments are in the format "edited by – John Doe"
    def process_coauthor_comment(comment)
      parts = comment.split(' – ')

      return nil unless parts.size == 2 # Not a coauthor comment

      role_string = parts[0].squish
      name = parts[1].squish
      role = ROLE_STRINGS.keys.detect { |role| ROLE_STRINGS[role].include?(role_string) }

      if role.nil?
        # raising an exception to find all relevant role strings
        # This is intentional, please don't remove!
        raise "Unknown role string: #{role_string}"
      end

      return LexLinkedPerson.new(name: name, link_type: role)
    end

    # some comments may have form 'about <Person name>'
    def process_prefix_comment(comment, prefix, link_type)
      if comment.start_with?("#{prefix} ")
        name = comment[(prefix.length + 1)..].squish
        return LexLinkedPerson.new(name: name, link_type: link_type)
      end
    end

    # It is kind-of difficult to parse Html document as-is, so we initially parse plain text of the comment
    # and then try to find in html element anchors with matching names in this method. In theory it can produce
    # false-positive findings, but in most cases it should be OK.
    def link_person_to_lex_entry(linked_person, element)
      element.css('a').each do |link|
        link_text = link.text.squish
        href = link['href']

        if link_text == linked_person.name && LexFile.person_filename?(href)
          # NOTE: it can be null if link is broken
          linked_person.person_entry = LexFile.find_by(fname: href)&.lex_entry
        end
      end
    end
  end
end
