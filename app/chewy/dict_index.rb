# frozen_string_literal: true

class DictIndex < Chewy::Index
  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }

  # DictionaryEntries
  index_scope DictionaryEntry.all

  field :id, type: 'integer'
  field :manifestation_id, type: 'integer'
  field :defhead
  field :deftext, value: ->(entry) { html2txt(entry.deftext).gsub("\n\n\n", "\n\n") }
  field :aliases, type: 'keyword', value: ->(entry) { entry.aliases.map(&:alias) }
end
