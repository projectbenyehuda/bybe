# frozen_string_literal: true

# Work created by LexPerson. It contains only basic metadata and optional link to LexPublication.
class LexPersonWork < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', foreign_key: :lex_person_id, inverse_of: :works
  belongs_to :lex_publication, class_name: 'LexPublication', optional: true

  # Optional sub-heading this work is listed under within its work-type section, e.g. עיון under
  # the original works. See LexPersonWorkGroup.
  belongs_to :work_group, class_name: 'LexPersonWorkGroup', inverse_of: :works,
                          foreign_key: :lex_person_work_group_id, optional: true

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
  before_validation :reconcile_work_group_and_type

  validates :title, :work_type, presence: true
  validate :collection_belongs_to_publication
  validate :work_group_matches_person_and_type
  validates :seqno, presence: true, numericality: { only_integer: true, greater_than: 0 }

  enum :work_type, { original: 0, translated: 1, edited: 2, festschrift: 3 }, prefix: true

  private

  # A sub-heading belongs to one work type, so a work's group and type have to agree. Whichever of
  # the two the editor actually changed wins: putting a work under a sub-heading moves it to that
  # sub-heading's type, and changing a work's type takes it out of its old section's sub-heading.
  def reconcile_work_group_and_type
    return if work_group.nil?

    # Compared by id only for a saved work: during ingest the work and its group are both unsaved,
    # so no id has changed yet, and the group is all the work was given.
    if persisted? && work_type_changed? && !lex_person_work_group_id_changed?
      self.work_group = nil
    else
      self.work_type = work_group.work_type
    end
  end

  def work_group_matches_person_and_type
    return if work_group.nil?

    # The records, not their ids: when ingest saves a person, the first work under a new group is
    # validated before the group itself is saved and handed the person's id.
    errors.add(:work_group, :belongs_to_different_person) if work_group.person != person
    errors.add(:work_group, :different_work_type) if work_group.work_type != work_type
  end

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
