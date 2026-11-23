# frozen_string_literal: true

# A sub-heading within one work-type section of a lexicon person's works: 00421.php splits its
# original works under שירה ופרוזה and עיון, 01661.php its edited works under
# עריכת תרגום - ספרי עיון and עריכת מקור - ספרי עיון. Each one is a named, ordered bucket of the
# person's works of that type; works of the type that sit under no sub-heading are listed first.
#
# Changing a group's work type takes its works along with it. Deleting a group returns its works
# to the ungrouped list of their type rather than destroying them -- an editor removing a heading
# means "these are just works", never "throw these away".
class LexPersonWorkGroup < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', inverse_of: :work_groups, foreign_key: :lex_person_id

  # Never autosaved from here: during ingest the works reach this collection through inversing,
  # and saving them with the group would insert them before LexPerson has given them its id.
  has_many :works, class_name: 'LexPersonWork', inverse_of: :work_group, dependent: :nullify, autosave: false

  enum :work_type, LexPersonWork.work_types, prefix: true, validate: true

  validates :title, :work_type, presence: true
  validates :title, uniqueness: { scope: %i(lex_person_id work_type) }

  scope :ordered, -> { order(:seqno, :id) }

  before_validation do
    self.title = title&.strip.presence
    # A new group, or one moved to another section, goes last among that section's groups. Read
    # through the association rather than with a MAX query: during ingest the person is still
    # unsaved and its groups exist only in memory.
    self.seqno = nil if persisted? && work_type_changed?
    if seqno.nil? && person.present?
      siblings = person.work_groups.select { |g| g.work_type == work_type && !g.equal?(self) }
      self.seqno = (siblings.filter_map(&:seqno).max || 0) + 1
    end
  end

  after_update :move_works_to_work_type, if: :saved_change_to_work_type?

  private

  # update_all rather than saving each work: LexPersonWork resets a work's group when its type
  # changes on its own, which is exactly what must not happen here.
  def move_works_to_work_type
    works.update_all(work_type: self.class.work_types[work_type], updated_at: Time.current)
  end
end
