# frozen_string_literal: true

# Concern for KWIC concordance functionality shared between controllers
module KwicConcordanceConcern
  extend ActiveSupport::Concern

  private

  def format_concordance_as_text(concordance_data)
    output = []
    output << "קונקורדנציה בתבנית KWIC"
    output << "=" * 50
    output << ""

    concordance_data.each do |entry|
      token = entry[:token]
      instances = entry[:instances]

      output << "מילה: #{token}"
      output << "-" * 40

      instances.each do |instance|
        label = instance[:label]
        paragraph = instance[:paragraph]
        before_context = instance[:before_context]
        after_context = instance[:after_context]

        line = "[#{label}, פסקה #{paragraph}] "
        line += "#{before_context} " if before_context.present?
        line += "[#{token}]"
        line += " #{after_context}" if after_context.present?

        output << line
      end

      output << ""
    end

    output.join("\n")
  end
end
