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

  # Recalculate intellectual property when authorities change
  after_commit :recalculate_expression_intellectual_property

  private

  def recalculate_expression_intellectual_property
    # Find the expression(s) affected by this authority change
    expressions = if item.is_a?(Expression)
                    [item]
                  elsif item.is_a?(Work)
                    item.expressions
                  else
                    []
                  end

    expressions.each do |expression|
      # Get all involved authorities for this expression (from both work and expression levels)
      manifestation = expression.manifestations.first
      next unless manifestation

      authority_ids = manifestation.involved_authorities.map(&:authority_id).uniq
      computed_ip = ComputeIntellectualProperty.call(authority_ids)

      # Only update if the computed value differs from current value
      if expression.intellectual_property != computed_ip.to_s
        expression.update_column(:intellectual_property, Expression.intellectual_properties[computed_ip])
      end
    end
  end
end
