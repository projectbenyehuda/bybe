# frozen_string_literal: true

# A sub-heading of the general citations about a lexicon person: ספרים, מאמרים, ספרי יובל,
# ביבליוגרפיה and the like. The legacy PHP bibliographies carry these as bare <font> headers above
# each <ul>, and the distinction between them is editorial information worth keeping, so each one
# becomes a named, ordered bucket a general citation can belong to.
#
# Only general citations are grouped: a citation about one of the person's works is already grouped
# by that work. Deleting a group returns its citations to the ungrouped general list rather than
# destroying them -- an editor removing a heading means "these are just general", never "throw these
# away".
class LexCitationGroup < ApplicationRecord
  belongs_to :person, class_name: 'LexPerson', inverse_of: :citation_groups, foreign_key: :lex_person_id

  has_many :citations, class_name: 'LexCitation', inverse_of: :citation_group, dependent: :nullify

  validates :title, presence: true, uniqueness: { scope: :lex_person_id }

  scope :ordered, -> { order(:seqno, :id) }

  before_validation do
    self.title = title&.strip.presence
    # Read through the association rather than with a MAX query: during ingest the person is still
    # unsaved and its groups exist only in memory.
    siblings = person.nil? ? [] : person.citation_groups
    self.seqno ||= (siblings.filter_map(&:seqno).max || 0) + 1
  end
end
