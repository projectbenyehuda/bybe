# frozen_string_literal: true

# A legacy bibliography groups the citations that are about the person -- as opposed to about one
# particular work of theirs -- under sub-headings of its own: ספרים, מאמרים, ספרי יובל,
# ביבליוגרפיה. Until now the migration threw those away, conflating every group into one flat
# "general" list. A LexCitationGroup is one such sub-heading: a named, ordered bucket of general
# citations belonging to a person.
#
# Only general citations are grouped. A citation about a work is already grouped by that work
# (LexPersonWork#citations_about), so lex_citation_group_id and lex_person_work_id are mutually
# exclusive -- see LexCitation#citation_group_only_on_general_citation.
class CreateLexCitationGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :lex_citation_groups do |t|
      t.references :lex_person, null: false, foreign_key: true
      t.string :title, null: false
      t.integer :seqno, null: false
      t.timestamps
    end

    # One heading of a given name per person: renaming a heading onto an existing one would
    # otherwise leave two indistinguishable groups an editor cannot tell apart.
    add_index :lex_citation_groups, %i(lex_person_id title), unique: true,
                                                             name: 'index_lex_citation_groups_on_person_and_title'

    add_reference :lex_citations, :lex_citation_group, null: true, foreign_key: true
  end
end
