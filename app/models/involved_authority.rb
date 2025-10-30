# frozen_string_literal: true

# This record represent relation between authorities and texts. Text can be represented either as Work or Expression
# instance, but not both.
class InvolvedAuthority < ApplicationRecord
  belongs_to :authority, inverse_of: :involved_authorities
  belongs_to :item, polymorphic: true, inverse_of: :involved_authorities, optional: false

  enum :role, {
    author: 0,
    editor: 1,
    illustrator: 2,
    translator: 3,
    photographer: 4,
    designer: 5,
    contributor: 6,
    other: 7
  }, prefix: true

  WORK_ROLES = (roles.keys - %w(translator)).freeze
  EXPRESSION_ROLES = (roles.keys - %w(author)).freeze
  ROLES_PRESENTATION_ORDER = %w(author illustrator photographer translator editor designer contributor other).freeze

  validates :role, presence: true
  validates :role, inclusion: WORK_ROLES, if: ->(ia) { ia.item.is_a? Work }
  validates :role, inclusion: EXPRESSION_ROLES, if: ->(ia) { ia.item.is_a? Expression }
  validates :authority_id, uniqueness: { scope: %i(item_type item_id role) }

  after_commit :update_manifestation_responsibility_statement, on: %i[create update destroy]

  private

  def update_manifestation_responsibility_statement
    manifestations = find_related_manifestations
    manifestations.each(&:recalc_responsibility_statement!)
  end

  def find_related_manifestations
    case item
    when Work
      item.expressions.flat_map(&:manifestations)
    when Expression
      item.manifestations
    else
      []
    end
  end
end
