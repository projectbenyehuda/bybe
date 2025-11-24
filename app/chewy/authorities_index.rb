# frozen_string_literal: true

# Index representing all published Authorities
class AuthoritiesIndex < Chewy::Index
  index_scope Authority.published.preload(:person, :corporate_body)
  field :id, type: 'integer'
  field :name
  field :sort_name, type: 'keyword'
  field :other_designation

  field :person do
    field :period, type: 'keyword'
    field :gender, type: 'keyword'
    field :birth_year, type: 'integer', value: ->(p) { p.birth_year == '?' ? nil : p.birth_year.to_i }
    field :death_year, type: 'integer', value: ->(p) { p.death_year == '?' ? nil : p.death_year.to_i }
  end

  field :corporate_body do
    field :location
    field :inception_year, type: 'integer'
    field :dissolution_year, type: 'integer'
  end

  field :any_hebrew_works, type: 'boolean', value: ->(a) { a.any_hebrew_works? }
  field :any_non_hebrew_works, type: 'boolean', value: ->(a) { a.any_non_hebrew_works? }
  field :impressions_count, type: 'integer'
  field :language, value: ->(a) { a.all_languages }, type: 'keyword'
  field :genre, value: ->(a) { a.all_genres }, type: 'keyword'
  field :intellectual_property, type: 'keyword'
  field :pby_publication_date, type: 'date', value: ->(a) { a.published_at }
  field :wikipedia_snippet
  field :tags, type: 'keyword', value: -> { approved_tags.map(&:name) }
  field :cached_works_count, type: 'integer', value: ->(a) { a.cached_works_count }
end
