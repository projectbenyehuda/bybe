class LexCitation < ApplicationRecord
  belongs_to :item, polymorphic: true
  belongs_to :manifestation
end
