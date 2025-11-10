# frozen_string_literal: true

# Service to parse a KWIC concordance text file back into structured data
class ParseKwicConcordance < ApplicationService
  # @param kwic_text [String] The KWIC concordance text file content
  # @return [Array<Hash>] Array of token entries, each containing:
  #   - :token [String] The token (word)
  #   - :instances [Array<Hash>] Array of occurrences, each with:
  #     - :label [String] Source text label
  #     - :before_context [String] Context before the token
  #     - :after_context [String] Context after the token
  #     - :paragraph [Integer] Paragraph number
  def call(kwic_text)
    return [] if kwic_text.blank?

    concordance_data = []
    current_token = nil
    current_instances = []

    kwic_text.each_line do |line|
      line = line.strip

      # Skip header and separator lines
      next if line.start_with?('קונקורדנציה בתבנית KWIC', '====', '----')
      next if line.empty?

      # Check if this is a token line
      if line.start_with?('מילה: ')
        # Save previous token if exists
        if current_token.present?
          concordance_data << {
            token: current_token,
            instances: current_instances
          }
        end

        # Start new token
        current_token = line.sub('מילה: ', '')
        current_instances = []
      elsif line.start_with?('[') && current_token.present?
        # Parse instance line: [label, פסקה N] before_context [TOKEN] after_context
        if line =~ /^\[(.+?), פסקה (\d+)\]\s*(.*)/
          label = ::Regexp.last_match(1)
          paragraph = ::Regexp.last_match(2).to_i
          context_part = ::Regexp.last_match(3)

          # Split context around [TOKEN]
          before_context = ''
          after_context = ''

          if context_part =~ /^(.*?)\s*\[#{Regexp.escape(current_token)}\]\s*(.*)/
            before_context = ::Regexp.last_match(1).strip
            after_context = ::Regexp.last_match(2).strip
          end

          current_instances << {
            label: label,
            paragraph: paragraph,
            before_context: before_context,
            after_context: after_context
          }
        end
      end
    end

    # Don't forget the last token
    if current_token.present?
      concordance_data << {
        token: current_token,
        instances: current_instances
      }
    end

    concordance_data
  end
end
