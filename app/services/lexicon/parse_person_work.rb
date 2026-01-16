# frozen_string_literal: true

module Lexicon
  # Service to parse works of Lexicon Person
  class ParsePersonWork
    def self.call(html)
      new.call(html)
    end

    def call(line)
      line = line.strip
      result = LexPersonWork.new

      # Extract comment if exists
      if line.match(/<(.+?)>/)
        result.comment = ::Regexp.last_match(1)
        line = line.gsub(/<.+?>/, '').strip
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
  end
end
