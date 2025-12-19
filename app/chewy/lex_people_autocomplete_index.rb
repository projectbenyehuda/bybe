# frozen_string_literal: true

# Lightweight index for autocomplete fields
class LexPeopleAutocompleteIndex < Chewy::Index
  index_scope LexPerson.preload(:entry).all
  field :id, type: 'integer'
  field :title, type: 'search_as_you_type', value: ->(person) { person.entry.title }
  field :status, type: 'keyword', value: ->(person) { person.entry.status }
end
