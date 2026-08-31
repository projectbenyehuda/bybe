# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod
  include LexEntryItem

  enum :gender, { male: 0, female: 1, other: 2, unknown: 3 }

  has_many :citations, inverse_of: :person, class_name: 'LexCitation', dependent: :destroy
  # Sub-headings of the general citations (ספרים, מאמרים, ...) -- see LexCitationGroup
  has_many :citation_groups, -> { ordered }, inverse_of: :person, class_name: 'LexCitationGroup',
                                             dependent: :destroy
  has_many :works, inverse_of: :person, class_name: 'LexPersonWork', dependent: :destroy

  belongs_to :authority, optional: true # link to an Authority record representing this person in BYP

  def general_citations
    citations.where(lex_person_work_id: nil, subject: nil).includes(:authors, :manifestation)
  end

  # Publications of the associated Authority that are not linked to any of this person's works,
  # i.e. works we know of in BYP that are missing from the legacy lexicon entry.
  def unmatched_publications
    return Publication.none if authority.nil?

    matched_ids = works.where.not(publication_id: nil).select(:publication_id)
    authority.publications.where.not(id: matched_ids).order(:title)
  end

  # Returns the intellectual_property string for display purposes.
  # Maps the boolean copyrighted field: true => 'copyrighted', false => 'public_domain', nil => nil
  def intellectual_property
    return nil if copyrighted.nil?

    copyrighted? ? 'copyrighted' : 'public_domain'
  end

  def gender_letter
    female? ? 'ה' : 'ו'
  end

  # Returns the LexEntry that links to this person
  def lex_entry
    entry
  end

  def works_by_type(work_type)
    work_type = work_type.to_s
    works.select { |w| w.work_type == work_type }
  end

  def max_work_seqno_by_type(work_type)
    works_by_type(work_type).map(&:seqno).max || 0
  end

  # Citations displayed under one heading, identified by LexCitation#group_token: a general
  # sub-heading ('heading:<id>'), a work or legacy subject title, or nil for the citations that
  # are general and carry no sub-heading.
  def citations_by_group_token(group_token)
    citations.select { |c| c.group_token == group_token }
  end

  def max_citation_seqno_by_group_token(group_token, exclude_citation_id: nil)
    cits = citations_by_group_token(group_token)
    cits = cits.reject { |c| c.id == exclude_citation_id } if exclude_citation_id.present?
    cits.map(&:seqno).compact.max || 0
  end

  # Whether any citation still carries a legacy subject heading, i.e. is not reachable from the
  # work it is about (see Lexicon::MatchCitationSubjects).
  def unresolved_citation_subjects?
    citations.where.not(subject: nil).exists?
  end

  # Resolves one legacy citation subject heading: every citation still carrying it is pointed at
  # `work` (or left general, when it is nil) and loses the heading string. The two go together --
  # LexCitation validates the subject away once a person_work is present.
  #
  # @param subject [String] the heading as stored on the citations
  # @param work [LexPersonWork, nil] the work the heading names, or nil for a general heading
  # @return [Integer] how many citations were resolved
  def link_citations_with_subject!(subject, work)
    resolved = citations.where(subject: subject).to_a
    resolved.each { |citation| citation.update!(person_work: work, subject: nil) }
    resolved.size
  end

  # Resolves one legacy citation subject heading the other way: as a sub-heading of the general
  # citations rather than the title of a work (see LexCitationGroup). Every citation still carrying
  # the heading moves under a group of that name, which is created if this is the first one.
  #
  # @param subject [String] the heading as stored on the citations
  # @param title [String] the name to give the group, defaulting to the heading itself
  # @return [Integer] how many citations were resolved
  def group_citations_with_subject!(subject, title = subject)
    group = citation_groups.find_or_create_by!(title: title.strip)
    resolved = citations.where(subject: subject).to_a
    resolved.each { |citation| citation.update!(citation_group: group, subject: nil) }
    resolved.size
  end
end
