# frozen_string_literal: true

# Sometimes LexPersonWork can have one or more coauthors stated (e.g. co-writers, editors, etc.).
# This model represents such coauthors, with optional link to LexEntry if the coauthor is also a known person in the
# lexicon.
class LexLinkedPerson < ApplicationRecord
  # We may consider changing this relation to be polymorphic if we'll need to link lex people to other
  # types of entities
  belongs_to :person_work,
             class_name: 'LexPersonWork',
             foreign_key: :lex_person_work_id

  # TODO: consider changing this relation to reference LexPeople instead of LexEntry, after whole lexicon migration
  #   will be done
  belongs_to :person_entry,
             class_name: 'LexEntry',
             foreign_key: :person_lex_entry_id,
             optional: true

  enum :link_type,
       {
         author: 1,
         editor: 2,
         illustrator: 3,
         collaborator: 4,
         about: 99
       },
       prefix: true

  validates :name, :link_type, presence: true
  validates :seqno, presence: true, numericality: { only_integer: true, greater_than: 0 }

  validate :validate_person_entry

  # value used for sorting items in the list
  def sort_value
    [seqno, id]
  end

  private

  def validate_person_entry
    return if person_lex_entry_id.nil?

    return if person_entry.lex_item_id.present? && person_entry.lex_item_type == 'LexPerson'

    return if person_entry.lex_item_id.nil? && person_entry.lex_file&.entrytype_person?

    errors.add(:person_entry, :not_a_person)
  end
end
