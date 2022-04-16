class LexLink < ApplicationRecord
  belongs_to :item, polymorphic: true
end
