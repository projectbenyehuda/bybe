# frozen_string_literal: true

# Work created by LexPerson. It contains only basic metadata and optional link to LexPublication.
class LexPersonWork < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', foreign_key: :lex_person_id, inverse_of: :works
  belongs_to :lex_publication, class_name: 'LexPublication', optional: true

  # Association with BYP Publication and Collection.
  # The collection is autosaved because picking a publication may link the collection to it, see
  # #link_collection_to_publication below.
  belongs_to :publication, optional: true
  belongs_to :collection, optional: true, autosave: true

  # Citations about this work
  has_many :citations_about,
           inverse_of: :person_work, class_name: 'LexCitation',
           dependent: :destroy

  # Other people linked to this work
  has_many :linked_people,
           inverse_of: :person_work,
           class_name: 'LexLinkedPerson',
           dependent: :destroy

  before_validation :link_collection_to_publication

  validates :title, :work_type, presence: true
  validate :collection_belongs_to_publication
  validates :seqno, presence: true, numericality: { only_integer: true, greater_than: 0 }

  enum :work_type, { original: 0, translated: 1, edited: 2, festschrift: 3 }, prefix: true

  private

  # When both a publication and a collection are chosen but the collection isn't linked to any
  # publication yet, link the two rather than rejecting the save. A collection already claimed by a
  # *different* publication is left alone, and still fails validation below: re-pointing it would
  # silently strip the other publication of its volume.
  def link_collection_to_publication
    return if publication_id.blank? || collection.blank?
    return if collection.publication_id.present?

    collection.publication_id = publication_id
  end

  def collection_belongs_to_publication
    return unless collection_id.present? && publication_id.present?
    return unless collection.publication_id != publication_id

    errors.add(:collection, :belongs_to_other_publication)
  end
end
