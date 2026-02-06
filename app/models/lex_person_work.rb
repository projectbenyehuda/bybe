# frozen_string_literal: true

# Work created by LexPerson. It contains only basic metadata and optional link to LexPublication.
class LexPersonWork < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', foreign_key: :lex_person_id, inverse_of: :works
  belongs_to :lex_publication, class_name: 'LexPublication', optional: true

  # Association with BYP Publication and Collection
  belongs_to :publication, optional: true
  belongs_to :collection, optional: true

  # Citations about this work
  has_many :citations_about,
           inverse_of: :person_work, class_name: 'LexCitation',
           dependent: :destroy

  validates :title, :work_type, presence: true
  validate :collection_belongs_to_publication
  validates :seqno, presence: true, numericality: { only_integer: true, greater_than: 0 }

  enum :work_type, { original: 0, translated: 1, edited: 2 }, prefix: true

  before_validation :assign_seqno, on: :create

  # Class method to reorder works
  def self.reorder_work(work_id, new_position)
    work = find(work_id)
    works = where(lex_person_id: work.lex_person_id, work_type: work.work_type)
                .order(:seqno)
                .to_a

    old_position = works.index(work)
    return if old_position.nil? || old_position == new_position

    # Remove from old position
    works.delete_at(old_position)
    # Insert at new position
    works.insert(new_position, work)

    # Reassign seqno values
    works.each_with_index do |w, index|
      w.update_column(:seqno, index + 1)
    end
  end

  private

  def assign_seqno
    return if seqno.present?

    max_seqno = self.class.where(lex_person_id: lex_person_id, work_type: work_type).maximum(:seqno) || 0
    self.seqno = max_seqno + 1
  end

  def collection_belongs_to_publication
    return unless collection_id.present? && publication_id.present?
    return unless collection.publication_id != publication_id

    errors.add(:collection, 'must belong to the selected publication')
  end
end
