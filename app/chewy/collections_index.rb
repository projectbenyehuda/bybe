# frozen_string_literal: true

# Index representing all published Collections
class CollectionsIndex < Chewy::Index
  index_scope Collection.where.not(collection_type: %w(periodical_issue uncollected))
                        .preload(involved_authorities: :authority)
  field :id, type: :integer
  field :title
  field :alternate_titles
  field :subtitle
  field :collection_type
  field :involved_authorities_string, value: lambda { |c|
    c.involved_authorities.preload(:authority).map { |ia| ia.authority.name }.join(', ')
  }
  field :impressions_count, type: :integer
  # field :any_public_manifestations, type: :boolean, value: lambda { |c|
  #   c.flatten_items.any? { |ci| ci.item_type == 'Manifestation' && ci.item.present? && ci.item.public? }
  # }
end
