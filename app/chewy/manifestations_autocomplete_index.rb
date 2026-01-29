# frozen_string_literal: true

# Lightweight index for autocomplete fields (includes non-published records too)
class ManifestationsAutocompleteIndex < Chewy::Index
  settings index: {
    number_of_shards: 1,
    number_of_replicas: 1
  }

  index_scope Manifestation.with_involved_authorities
  field :id, type: 'integer'
  field :title, type: 'search_as_you_type'
  field :alternate_titles, type: 'search_as_you_type'
  field :title_and_authors
  field :expression_id, type: 'integer' # Not sure if we need this, but it was returned by SQL autocomplete
  field :published, type: 'boolean', value: ->(m) { m.published? }
end
