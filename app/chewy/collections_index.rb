# frozen_string_literal: true

# Index representing all published Collections
class CollectionsIndex < Chewy::Index
  settings index: {
    number_of_shards: 1,
    number_of_replicas: 0
  }

  index_scope Collection.where.not(collection_type: %w(periodical_issue uncollected))
                        .preload(involved_authorities: :authority)
  field :id, type: :integer
  field :title
  field :sort_title
  field :alternate_titles
  field :subtitle
  field :collection_type
  field :involved_authorities_string, value: lambda { |c|
    c.involved_authorities.preload(:authority).map { |ia| ia.authority.name }.join(', ')
  }
  field :involved_authority_ids, value: ->(c) { c.involved_authorities.pluck(:authority_id) }
  field :involved_authority_roles, value: ->(c) { c.involved_authorities.pluck(:role).uniq }
  field :impressions_count, type: :integer
  # field :any_public_manifestations, type: :boolean, value: lambda { |c|
  #   c.flatten_items.any? { |ci| ci.item_type == 'Manifestation' && ci.item.present? && ci.item.public? }
  # }
  field :tags, value: ->(c) { c.tags.pluck(:id) }
  field :first_letter, value: lambda { |c|
    c.sort_title.present? ? c.sort_title[0].downcase : 'א'
  }
  field :items_count, type: :integer, value: ->(c) { c.collection_items.count }
  field :inception_year, type: :integer
  field :normalized_pub_year, type: :integer
end
