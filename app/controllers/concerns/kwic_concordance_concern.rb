# frozen_string_literal: true

# Concern for KWIC concordance functionality shared between controllers
module KwicConcordanceConcern
  extend ActiveSupport::Concern

  private

  # Ensure a KWIC downloadable exists for the given entity (Manifestation or Collection)
  # Uses the fresh downloadable mechanism to avoid regenerating if already exists
  def ensure_kwic_downloadable_exists(entity)
    dl = entity.fresh_downloadable_for('kwic')
    return if dl.present? # Already exists and is fresh

    # Generate and save the downloadable
    if entity.is_a?(Collection)
      labelled_texts = []
      entity.flatten_items.each do |ci|
        next if ci.item.nil? || ci.item_type != 'Manifestation'

        labelled_texts << {
          label: ci.title,
          buffer: ci.item.to_plaintext
        }
      end
      kwic_text = GenerateKwicConcordance.call(labelled_texts)
      filename = "#{entity.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.kwic"
      austr = textify_authorities_and_roles(entity.involved_authorities)
      MakeFreshDownloadable.call('kwic', filename, '', entity, austr, kwic_text: kwic_text)
    elsif entity.is_a?(Manifestation)
      labelled_texts = [{
        label: entity.title,
        buffer: entity.to_plaintext
      }]
      kwic_text = GenerateKwicConcordance.call(labelled_texts)
      filename = "#{entity.title.gsub(/[^0-9א-תA-Za-z.\-]/, '_')}.kwic"
      involved_auths = entity.expression.involved_authorities + entity.expression.work.involved_authorities
      austr = textify_authorities_and_roles(involved_auths)
      MakeFreshDownloadable.call('kwic', filename, '', entity, austr, kwic_text: kwic_text)
    end
  end

  def format_concordance_as_text(concordance_data)
    output = []
    output << 'קונקורדנציה בתבנית KWIC'
    output << ('=' * 50)
    output << ''

    concordance_data.each do |entry|
      token = entry[:token]
      instances = entry[:instances]

      output << "מילה: #{token}"
      output << ('-' * 40)

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

      output << ''
    end

    output.join("\n")
  end
end
