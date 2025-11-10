class Recommendation < ApplicationRecord
  belongs_to :user
  belongs_to :approver, foreign_key: 'approved_by', class_name: 'User', optional: true
  belongs_to :manifestation

  enum :status, { pending: 0, approved: 1 }
end
