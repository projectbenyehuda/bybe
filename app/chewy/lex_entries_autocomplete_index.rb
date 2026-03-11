# frozen_string_literal: true

# Lightweight index for autocomplete fields, covering all LexEntry records
class LexEntriesAutocompleteIndex < Chewy::Index
  index_scope LexEntry.preload(:lex_item, :lex_file).all
  field :id, type: 'integer'
  field :title, type: 'search_as_you_type'
  field :entry_type, type: 'keyword', value: ->(entry) { entry.entry_type }
end
