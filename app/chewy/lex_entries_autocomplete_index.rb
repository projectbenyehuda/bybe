# frozen_string_literal: true

# Lightweight index for autocomplete fields, covering all LexEntry records
class LexEntriesAutocompleteIndex < Chewy::Index
  # See LexEntriesIndex: the same normalization, so that typing "כץ" offers "יואב כ״ץ" here
  # just as searching for it finds the entry there. search_as_you_type propagates the analyzer
  # to the _2gram/_3gram/_index_prefix subfields it generates.
  settings analysis: {
    char_filter: {
      hebrew_search: {
        type: 'mapping',
        mappings: Lexicon::NormalizeSearchText.elasticsearch_mappings
      }
    },
    analyzer: {
      hebrew_search: {
        type: 'custom',
        char_filter: %w(hebrew_search),
        tokenizer: 'standard',
        filter: %w(lowercase)
      }
    }
  }

  index_scope LexEntry.preload(:lex_item, :lex_file).all
  field :id, type: 'integer'
  field :title, type: 'search_as_you_type', analyzer: 'hebrew_search'
  field :entry_type, type: 'keyword', value: ->(entry) { entry.entry_type }
end
