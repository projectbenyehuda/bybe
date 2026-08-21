# frozen_string_literal: true

# Add english_title and external_identifiers fields to lex_entries for lexicon migration
class AddEnglishTitleAndExternalIdentifiersToLexEntry < ActiveRecord::Migration[8.0]
  def change
    change_table :lex_entries, bulk: true do |t|
      t.string :english_title
      t.json :external_identifiers
    end
  end
end
