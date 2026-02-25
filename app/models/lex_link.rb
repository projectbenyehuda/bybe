# frozen_string_literal: true

# Link related to lexicon entry
class LexLink < ApplicationRecord
  belongs_to :item, polymorphic: true, inverse_of: :links

  validates :url, presence: true

  # Returns true if the link was checked and returned a 4xx or 5xx status code.
  def broken?
    http_status.present? && http_status >= 400
  end
end
