# frozen_string_literal: true

# Service to generate a KWIC (Key Word In Context) concordance text file
# from labelled texts
class GenerateKwicConcordance < ApplicationService
  include BybeUtils

  # @param labelled_texts [Array<Hash>] Array of text entries, each with :label and :buffer keys
  # @return [String] Formatted KWIC concordance as plain text
  def call(labelled_texts)
    concordance_data = kwic_concordance(labelled_texts)

    # Format the concordance as plain text
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

        # Format: [label, paragraph] ... before_context [TOKEN] after_context ...
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
