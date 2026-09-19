# frozen_string_literal: true

# Index representing published Lexicon Entries (for now only LexPeople records are supported)
class LexEntriesIndex < Chewy::Index
  # Applied to both indexing and searching, so a query matches an entry whenever the two agree
  # once maqafim, geresh/gershayim and pointing are set aside -- in either direction, whichever
  # side of the comparison happens to carry them. See Lexicon::NormalizeSearchText.
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

  index_scope LexEntry.status_published
                      .preload(lex_item: { citations: %i(authors person_work), works: :lex_publication })

  field :id, type: :integer
  field :title, analyzer: 'hebrew_search'
  field :fulltext, type: 'text', analyzer: 'hebrew_search', value: lambda { |entry|
    if entry.lex_item.is_a? LexPerson
      Lexicon::LexPersonContent.call(entry.lex_item)
    end
  }
end
