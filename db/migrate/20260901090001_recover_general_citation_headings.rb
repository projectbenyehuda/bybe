# frozen_string_literal: true

# Restores the general sub-headings (ספרים, מאמרים, ספרי יובל, ...) that the migration used to
# throw away, for the entries already migrated without them.
#
# Two sources of loss are undone:
#
# 1. Headings still stored as a legacy LexCitation#subject. The recognized-general list was short
#    ('מאמרים', 'ספרים', 'על הספר') and did not allow for the trailing colon half the legacy files
#    write, so 'ספרים:' and 'ביבליוגרפיה' were never recognized and sat unresolved. They now become
#    LexCitationGroups keeping their name.
# 2. Headings already cleared, whose citations are flat general ones with nothing left to say which
#    group they came from. Those are re-read from the legacy PHP file --
#    Lexicon::RecoverCitationHeadings matches each general citation back to the <li> it was parsed
#    from and files it under that <li>'s heading.
#
# Both steps only ever touch citations that are general and ungrouped, so the migration is safe to
# re-run and cannot overrule an editor. Entries are deliberately not sent back to verification:
# recovery is conservative -- only headings on the recognized-general list are restored -- and adds
# information rather than changing any editorial decision.
#
# Step 2 needs the legacy PHP corpus to be readable at LexFile#full_path. Where it is not, the
# entry is counted as skipped and the migration carries on: a missing corpus must not fail a deploy,
# and the step can simply be re-run once it is mounted.
class RecoverGeneralCitationHeadings < ActiveRecord::Migration[8.0]
  def up
    group_recognized_subjects
    recover_cleared_headings
  end

  def down
    # Not reversible: the flat general list this restores structure to recorded nothing about which
    # sub-heading each citation came from -- that is the very loss being repaired.
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def group_recognized_subjects
    say 'Turning recognized general subject headings into sub-headings...'
    headings = 0
    citations = 0

    LexPerson.where(id: LexCitation.where.not(subject: nil).select(:lex_person_id)).find_each do |person|
      # Applied in source order, so the sub-headings come out in the order the legacy page had them
      # (ספרים before מאמרים) rather than the alphabetical order the proposals arrive in.
      Lexicon::MatchCitationSubjects.call(person).select(&:generic).sort_by(&:source_position).each do |proposal|
        citations += proposal.apply!(person)
        headings += 1
      end
    end

    say "grouped #{citations} citations under #{headings} headings", true
  end

  def recover_cleared_headings
    say 'Recovering cleared sub-headings from the legacy files...'
    recovered = Hash.new(0)
    skipped = Hash.new(0)

    LexPerson.where(id: ungrouped_general_citations.select(:lex_person_id)).find_each do |person|
      result = Lexicon::RecoverCitationHeadings.call(person)
      if result.skipped?
        skipped[result.skipped] += 1
      else
        recovered[:entries] += 1 if result.grouped_count.positive?
        recovered[:citations] += result.grouped_count
        recovered[:headings] += result.groups.size
      end
    rescue StandardError => e
      skipped[:error] += 1
      say "entry #{person.entry&.id}: #{e.class}: #{e.message}", true
    end

    say "recovered #{recovered[:headings]} headings over #{recovered[:citations]} citations " \
        "in #{recovered[:entries]} entries", true
    say "passed over: #{skipped.map { |reason, count| "#{reason}=#{count}" }.join(', ')}", true if skipped.any?
  end

  def ungrouped_general_citations
    LexCitation.where(lex_person_work_id: nil, lex_citation_group_id: nil, subject: nil)
  end
end
