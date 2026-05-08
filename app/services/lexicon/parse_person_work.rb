# frozen_string_literal: true

module Lexicon
  # Service to parse works of Lexicon Person
  class ParsePersonWork < ApplicationService
    include Rails.application.routes.url_helpers

    # rubocop:disable Style/WordArray
    ROLE_STRINGS = {
      illustrator: ['איורים', 'איור'],
      editor: ['עריכה'],
      collaborator: ['בשיתוף'],
      about: ['על']
    }.freeze
    # rubocop:enable Style/WordArray


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
        parts = comment_line.split(';').map(&:strip) # in most cases it will a single-element array

        parts.each do |comment|
          # At first checking if this is a coauthor comment
          linked_person = process_linked_person_comment(comment, element)

          if linked_person.present?
            linked_person.seqno = person_work.linked_people.size + 1
            person_work.linked_people << linked_person
          else
            plain_comments << comment
          end
        end
      end

      # All non-coauthor comments are stored as lines in coauthor comment field, separated by line breaks
      person_work.comment = plain_comments.join("\n") if plain_comments.present?
    end

    # Linked person comments are in the format 'editor – John Doe' (e.g. 'עריכה – יעל גובר')
    # Sometimes role can be separated by comma: 'editor, John Doe' (e.g. 'עריכה, שרי גוטמן')
    # There are also a cases when there are no special characters separating role and name, but role is still present:
    #   'in collaboration with John Doe' (e.g. 'בשיתוף זהר שוורץ')
    def process_linked_person_comment(comment, element)
      link_type = nil
      prefix = nil

      ROLE_STRINGS.each do |type, prefixes|
        prefix = prefixes.detect do |p|
          next false unless comment.start_with?(p)

          remaining = comment[p.length..]
          # prefix should be followed by ' ', ',', '–' or '-'
          remaining.present? && [' ', ',', '-', '–'].include?(remaining[0])
        end
        if prefix.present?
          link_type = type
          break
        end
      end

      return nil if link_type.nil?

      name = comment[(prefix.length + 1)..].strip
      name = name[1..].strip if %w(, – -).include?(name[0]) # removing optional separator character

      return nil if name.blank?

      return LexLinkedPerson.new(name: name, link_type: link_type, person_entry: find_person_entry(name, element))
    end

    # It is kind-of difficult to parse Html document as-is, so we initially parse plain text of the comment
    # and then try to find in html element anchors with matching names in this method. In theory it can produce
    # false-positive findings, but in most cases it should be OK.
    def find_person_entry(name, element)
      element.css('a').each do |link|
        link_text = link.text.squish
        next unless link_text == name

        href = link['href']
        # At this point source HTML should already have links to other lexicon pages
        # replaced with the links to corresponding LexEntries so we're looking for a link leading to Person LexEntry
        next unless href.start_with?(lexicon_entries_path + '/')

        entry_id = href.gsub(lexicon_entries_path + '/', '').to_i
        # NOTE: it can be null if link is broken
        entry = LexEntry.find_by(id: entry_id)
        return entry if entry&.lex_file&.entrytype_person?
      end

      return nil
    end
  end
end
