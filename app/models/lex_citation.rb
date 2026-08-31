# frozen_string_literal: true

# Citation about lexicon entry

# citations are not first-order entities in the lexicon. They are single-line references to texts about a lexicon
# author or a particular lexicon author's publication.
class LexCitation < ApplicationRecord
  include TrimsDuplicateUrlAnchor

  # mandatory relation to the person on whose page this citation appears
  # (it can be about this person, or about one of his/her works)
  belongs_to :person, class_name: 'LexPerson', inverse_of: :citations, foreign_key: :lex_person_id

  # optional LexPersonWork this citation is about (can be null if citation is general about the person)
  belongs_to :person_work,
             class_name: 'LexPersonWork', inverse_of: :citations_about,
             foreign_key: :lex_person_work_id, optional: true

  # optional sub-heading this citation sits under within the general (about-the-person) citations,
  # e.g. ספרים or מאמרים. Mutually exclusive with person_work: a citation about a work is already
  # grouped by that work.
  belongs_to :citation_group,
             class_name: 'LexCitationGroup', inverse_of: :citations,
             foreign_key: :lex_citation_group_id, optional: true

  belongs_to :manifestation, optional: true # manifestation representing this citation (if present in BYP)

  has_many :authors, class_name: 'LexCitationAuthor', inverse_of: :citation, dependent: :destroy

  has_one_attached :backup_file

  validates :title, presence: true

  validate :person_work_belongs_to_same_person
  validate :citation_group_belongs_to_same_person
  validate :citation_group_only_on_general_citation

  # Subject is a string title of the work this citation is about (if any) and filled during parsing of legacy PHP files.
  # We should replace all subjects with person_work references where possible, and then clear the subject field.
  # After Legacy data migration is done, we can drop subject field entirely.
  validates :subject, absence: true, if: -> { person_work.present? }

  before_validation do
    subject&.strip!
    self.subject = nil if subject.blank?
    self.link = trim_duplicate_url_anchor(link)
    self.backup_url = trim_duplicate_url_anchor(backup_url)
  end

  def subject_title
    return person_work&.title || subject
  end

  # Prefix marking a group token as naming a LexCitationGroup rather than a subject title.
  HEADING_TOKEN_PREFIX = 'heading:'

  # The full shape of such a token. Matching the prefix alone would not do: a work title or a
  # legacy subject heading is a group token in its own right, and one reading 'heading:whatever'
  # would be taken for a sub-heading it is not.
  HEADING_TOKEN_RE = /\A#{HEADING_TOKEN_PREFIX}(\d+)\z/

  # The id of the LexCitationGroup a group token names, or nil when it names anything else.
  def self.heading_token_group_id(group_token)
    group_token.to_s[HEADING_TOKEN_RE, 1]&.to_i
  end

  # Stable identifier of the heading this citation is displayed under: the key the citation lists
  # are grouped by, and the name a group goes by in the reordering endpoint.
  #
  # A general sub-heading is identified by id rather than by its title, because a person may well
  # have a work titled 'מאמרים' too, and keying both on the bare title would silently merge the
  # two groups. Work citations and citations still carrying a legacy subject heading do keep
  # sharing a key when their titles agree -- that is what lets a half-resolved bibliography show
  # one heading rather than two identical ones.
  def group_token
    return "#{HEADING_TOKEN_PREFIX}#{lex_citation_group_id}" if lex_citation_group_id.present?

    subject_title
  end

  # The displayed prose that text_links pairs are matched against (see
  # LexiconHelper#apply_text_links). Used to tell an editor when a pair's text
  # no longer occurs anywhere in the citation.
  def linkable_text
    [title, from_publication, notes].compact_blank.join(' ')
  end

  # Returns true if the citation link was checked and is inaccessible: either it
  # returned a 4xx/5xx status, or the host was unreachable (nil status after a
  # check). link_checked_at distinguishes "checked and dead" from "never checked".
  # Local/relative URLs (e.g. /files/lex/...) are never considered broken — they
  # are served by our own application and cannot be checked via HTTP HEAD.
  # A link the checker could not get a verdict on (see #link_unverifiable?) is not
  # broken: we simply do not know, and an editor has to look at it.
  def link_broken?
    return false if link.blank? || !link.start_with?('http://', 'https://')
    return false if link_unverifiable?

    link_checked_at.present? && (link_http_status.nil? || link_http_status >= 400)
  end

  private

  def person_work_belongs_to_same_person
    return if person_work.nil?
    return if person_work.lex_person_id == lex_person_id

    errors.add(:person_work, :belongs_to_different_person)
  end

  def citation_group_belongs_to_same_person
    return if citation_group.nil?
    return if citation_group.lex_person_id == lex_person_id

    errors.add(:citation_group, :belongs_to_different_person)
  end

  # A general sub-heading buckets citations about the person. A citation about one of the person's
  # works belongs under that work instead, so the two groupings can never both apply.
  def citation_group_only_on_general_citation
    return if citation_group.nil? || person_work.nil?

    errors.add(:citation_group, :not_on_work_citation)
  end
end
