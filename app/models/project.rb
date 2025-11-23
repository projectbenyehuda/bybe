# frozen_string_literal: true

class Project < ApplicationRecord
  validates :name, presence: true

  # Active projects have no end date or end date is in the future
  scope :active, -> { where('end_date IS NULL OR end_date >= ?', Date.current) }
end
