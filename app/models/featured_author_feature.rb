class FeaturedAuthorFeature < ApplicationRecord
  belongs_to :featured_author, inverse_of: :featurings

  validates :fromdate, :todate, presence: true
end
