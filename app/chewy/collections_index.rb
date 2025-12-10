# frozen_string_literal: true

# Index representing all published Collections
class CollectionsIndex < Chewy::Index
  index_scope Collection.where.not(collection_type: %w(periodical_issue uncollected))
                        .preload(involved_authorities: :authority)
  field :id, type: :integer
  field :title
  field :sort_title, type: :keyword # for sorting
  field :alternate_titles
  field :subtitle
  field :collection_type, type: :keyword # for filtering
  field :involved_authorities_string, value: lambda { |c|
    c.involved_authorities.preload(:authority).map { |ia| ia.authority.name }.join(', ')
  }
  field :involved_authority_ids, type: :integer, value: ->(c) { c.involved_authorities.pluck(:authority_id) }
  field :involved_authority_roles, type: :keyword, value: ->(c) { c.involved_authorities.pluck(:role).uniq }
  field :impressions_count, type: :integer
  field :tags, type: :integer, value: ->(c) { c.tags.pluck(:id) }
  field :first_letter, type: :keyword, value: lambda { |c|
    c.sort_title.present? ? c.sort_title[0].downcase : 'א'
  }
  field :items_count, type: :integer, value: ->(c) { c.collection_items.count }
  field :inception_year, type: :integer
  field :normalized_pub_year, type: :integer
end
