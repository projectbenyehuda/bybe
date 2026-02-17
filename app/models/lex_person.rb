# frozen_string_literal: true

# Person from Lexicon
class LexPerson < ApplicationRecord
  include LifePeriod
  include LexEntryItem

  update_index('lex_people_autocomplete') { self }

  enum :gender, { male: 0, female: 1, other: 2, unknown: 3 }

  has_many :citations, inverse_of: :person, class_name: 'LexCitation', dependent: :destroy
  has_many :citation_authors, class_name: 'LexCitationAuthor', dependent: :nullify
  has_many :works, inverse_of: :person, class_name: 'LexPersonWork', dependent: :destroy

  belongs_to :authority, optional: true # link to an Authority record representing this person in BYP

  def general_citations
    citations.where(lex_person_work_id: nil, subject: nil).includes(:authors, :manifestation)
  end

  def intellectual_property
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

  # TODO: after finishing Lexicon migration and removal of Lex_Citations.subject column
  #   we should pass lex_person_work_id here and rename method appropriately
  def citations_by_subject_title(subject_title)
    citations.select { |c| c.subject_title == subject_title }
  end

  def max_citation_seqno_by_subject_title(subject_title, exclude_citation_id: nil)
    cits = citations_by_subject_title(subject_title)
    cits = cits.reject { |c| c.id == exclude_citation_id } if exclude_citation_id.present?
    cits.map(&:seqno).compact.max || 0
  end
end
