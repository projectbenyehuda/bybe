# frozen_string_literal: true

class LexLink < ApplicationRecord
  belongs_to :item, polymorphic: true
end
