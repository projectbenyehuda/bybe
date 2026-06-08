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
        result.title_links = extract_title_links(element, line) if result.respond_to?(:title_links=)
        return result
      end

      # Extract title (everything before last '(')
      result.title = line[0...last_open_paren].strip
      result.title_links = extract_title_links(element, result.title) if result.respond_to?(:title_links=)

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
      comment_links = []

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
            # Plain comments may still embed person links (e.g. 'כולל אחרית דבר מאת <a>יגאל שוורץ</a>').
            # The comment is stored as plain text, so capture the links separately to keep them.
            comment_links.concat(extract_comment_links(comment, element))
          end
        end
      end

      # All non-coauthor comments are stored as lines in coauthor comment field, separated by line breaks
      person_work.comment = plain_comments.join("\n") if plain_comments.present?
      return unless person_work.respond_to?(:comment_links=)

      person_work.comment_links = comment_links.uniq { |link| link['text'] }.presence
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

    # Scans the HTML element for <a> tags whose text appears in the title portion (not in comment brackets)
    # and that link to person LexEntries. Returns an array of {text:, entry_id:} hashes.
    def extract_title_links(element, title_text)
      links = []
      # Comments in angle brackets are stripped from the line before the title is extracted,
      # and comment nodes in HTML are typically inside <font size="2"> wrappers.
      # We skip any anchor that is a descendant of such a comment wrapper.
      comment_hrefs = Set.new(element.css('font[size="2"] a').pluck('href'))

      element.css('a').each do |anchor|
        href = anchor['href']
        next unless href&.start_with?(lexicon_entries_path + '/')
        # skip anchors that belong to comment sections
        next if comment_hrefs.include?(href)

        link_text = anchor.text.squish
        # Only include if the link text actually appears in the title (not in publication details)
        next unless title_text.include?(link_text)

        entry_id = href.delete_prefix(lexicon_entries_path + '/').to_i
        entry = LexEntry.find_by(id: entry_id)
        next unless entry&.lex_file&.entrytype_person?

        links << { 'text' => link_text, 'entry_id' => entry_id }
      end

      links.presence
    end

    # Scans the comment-section <a> tags (inside <font size="2"> wrappers, the same convention
    # extract_title_links relies on to tell comment anchors apart from title anchors) whose text
    # appears within the given plain comment and that link to person LexEntries. Returns an array
    # of {text:, entry_id:} hashes so the link can be reconstructed when rendering the
    # (otherwise plain-text) comment.
    def extract_comment_links(comment, element)
      links = []
      element.css('font[size="2"] a').each do |anchor|
        href = anchor['href']
        next unless href&.start_with?(lexicon_entries_path + '/')

        link_text = anchor.text.squish
        next if link_text.blank?
        # Only include anchors whose text actually appears in this comment
        next unless comment.include?(link_text)
        next if links.any? { |l| l['text'] == link_text }

        entry_id = href.delete_prefix(lexicon_entries_path + '/').to_i
        entry = LexEntry.find_by(id: entry_id)
        next unless entry&.lex_file&.entrytype_person?

        links << { 'text' => link_text, 'entry_id' => entry_id }
      end
      links
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
