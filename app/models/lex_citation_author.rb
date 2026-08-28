# frozen_string_literal: true

# One author of a LexCitation: either a reference to the person's own lexicon entry, or the
# plaintext name the legacy PHP file carried when no entry could be resolved for it.
class LexCitationAuthor < ApplicationRecord
  belongs_to :citation, class_name: 'LexCitation', inverse_of: :authors, foreign_key: 'lex_citation_id'
  belongs_to :entry, optional: true, class_name: 'LexEntry', foreign_key: 'lex_entry_id'

  validates :name, presence: true, if: -> { entry.nil? }
  validates :lex_entry_id, uniqueness: { scope: :lex_citation_id }, allow_nil: true
  validates :link, absence: { message: :link_with_entry_error }, if: -> { entry.present? }
  validate :entry_must_be_person, if: -> { entry.present? }

  def display_name
    name.presence || entry&.title
  end

  # The name to look an existing entry up by (see .normalize_name).
  def normalized_name
    self.class.normalize_name(name)
  end

  # Legacy PHP files write citation authors as "lastname, firstname", which is never how a lexicon
  # entry is titled, so the surname is moved to the end and the comma dropped before looking the
  # name up. Names without a comma are returned as they stand.
  def self.normalize_name(name)
    return nil if name.blank?

    surname, given = name.split(',', 2)
    return surname.squish if given.blank?

    "#{given} #{surname}".squish
  end

  # The normalized names (downcased) of those among `authors` that are not linked to an entry yet
  # and for which at least one person-type LexEntry is titled exactly that. Resolved in a single
  # query, so a citation-heavy verification page costs one lookup rather than one per author.
  # Linked authors are recognised by their foreign key rather than by #entry, so the count stays
  # one whether or not the caller preloaded the association.
  def self.matchable_names(authors)
    names = authors.select { |author| author.lex_entry_id.nil? }
                   .filter_map(&:normalized_name)
                   .uniq
    return Set.new if names.empty?

    LexEntry.person_type.where(title: names).pluck(:title).to_set(&:downcase)
  end

  private

  def entry_must_be_person
    return if entry.nil?

    is_person = entry.lex_item.is_a?(LexPerson) ||
                entry.lex_file&.entrytype_person?

    errors.add(:entry, :not_a_person) unless is_person
  end
end
