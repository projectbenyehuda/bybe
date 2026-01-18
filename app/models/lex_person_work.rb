# frozen_string_literal: true

# Work created by LexPerson. It contains only basic metadata and optional link to LexPublication.
class LexPersonWork < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', foreign_key: :lex_person_id, inverse_of: :works
  belongs_to :lex_publication, class_name: 'LexPublication', optional: true

  # Association with BYP Publication and Collection
  belongs_to :publication, optional: true
  belongs_to :collection, optional: true

  validates :title, :work_type, presence: true
  validate :collection_belongs_to_publication

  enum :work_type, { original: 0, translated: 1, edited: 2 }, prefix: true

  private

  def collection_belongs_to_publication
    return unless collection_id.present? && publication_id.present?
    return unless collection.publication_id != publication_id

    errors.add(:collection, 'must belong to the selected publication')
  end
end
