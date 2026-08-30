# frozen_string_literal: true

# The legacy PHP bibliographies group the citations about a person under headings naming one of
# that person's works, and the migration stored each heading verbatim on every citation below it
# (LexCitation#subject). Ingest only ever linked a heading that matched a work title character for
# character, so most headings survived unresolved -- and a citation still carrying a heading is
# invisible to the public citations cards, which are driven by LexPersonWork#citations_about.
#
# This migration resolves what can be resolved without a human: headings that name exactly one work
# beyond doubt (identical once the "about" prefix, the subtitle and the punctuation are normalized
# away -- see Lexicon::MatchCitationSubjects). Everything else -- an approximate match, a heading
# fitting two works equally well, and the general "מאמרים"/"ספרים" buckets -- is left for an editor
# to confirm in the new citation-headings section of the verification workbench.
#
# Published entries that still hold an unresolved heading afterwards are therefore sent back to
# verification, with the new checklist section added so it counts towards their progress. Entries
# already under verification get the section too, so it counts for them as well.
class BackfillCitationSubjectPersonWorks < ActiveRecord::Migration[8.0]
  CHECKLIST_SECTION = 'citation_subjects'

  def up
    say 'Linking citation headings that name exactly one work...'
    linked_headings = 0
    linked_citations = 0

    LexPerson.where(id: LexCitation.where.not(subject: nil).select(:lex_person_id)).find_each do |person|
      Lexicon::MatchCitationSubjects.call(person).select(&:certain?).each do |proposal|
        linked_citations += person.link_citations_with_subject!(proposal.subject, proposal.work)
        linked_headings += 1
      end
    end

    say "linked #{linked_citations} citations under #{linked_headings} headings", true

    add_checklist_section
    reset_entries_with_unresolved_headings
  end

  def down
    # Not reversible: the headings the linked citations carried were cleared, and which citation
    # carried which heading is not recorded anywhere else.
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # verification_progress['checklist'] is built once, when verification starts, so entries that
  # began verification before this section existed would never count it towards their progress.
  def add_checklist_section
    added = 0
    LexEntry.where(lex_item_type: 'LexPerson').find_each do |entry|
      checklist = entry.verification_progress&.dig('checklist')
      next if checklist.blank? || checklist.key?(CHECKLIST_SECTION)

      progress = entry.verification_progress.deep_dup
      progress['checklist'][CHECKLIST_SECTION] = { 'verified' => false, 'notes' => '' }
      entry.update_columns(verification_progress: progress)
      added += 1
    end
    say "added the #{CHECKLIST_SECTION} checklist section to #{added} entries", true
  end

  # Only entries whose headings could not all be resolved mechanically need an editor to look at
  # them again; the rest are already correct and stay published.
  def reset_entries_with_unresolved_headings
    person_ids = LexCitation.where.not(subject: nil).select(:lex_person_id)
    reset = LexEntry.where(lex_item_type: 'LexPerson', lex_item_id: person_ids, status: :published)
                    .update_all(status: LexEntry.statuses[:verifying])
    say "sent #{reset} published entries back to verification", true
  end
end
