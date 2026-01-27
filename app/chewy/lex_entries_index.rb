# frozen_string_literal: true

# Index representing published Lexicon Entries (for now only LexPeople records are supported)
class LexEntriesIndex < Chewy::Index
  index_scope LexEntry.status_published
                      .preload(lex_item: { citations: %i(authors person_work), works: :lex_publication })

  field :id, type: :integer
  field :title
  field :fulltext, type: 'text', value: lambda { |entry|
    if entry.lex_item.is_a? LexPerson
      Lexicon::LexPersonContent.call(entry.lex_item)
    end
  }
end
