# frozen_string_literal: true

# Lightweight index for publications autocomplete fields
class PublicationsAutocompleteIndex < Chewy::Index
  index_scope Publication.all
  field :id, type: 'integer'
  field :title, type: 'search_as_you_type'
end
