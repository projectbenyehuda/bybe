# frozen_string_literal: true

# Language through which a translation was made, when not translated directly from the original
# (e.g. Tchernichowsky's Kalevala, translated from Russian rather than Finnish)
class AddMediatingLanguageToExpressionsAndIngestibles < ActiveRecord::Migration[8.0]
  def change
    add_column :expressions, :mediating_language, :string
    add_column :ingestibles, :mediating_language, :string
  end
end
