# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::RecoverCitationHeadings do
  subject(:call) { described_class.call(person) }

  let(:lex_file) do
    create(:lex_file, :person, status: :ingested, fname: 'general_citation_headings.php',
                               full_path: Rails.root.join('spec/fixtures/files/lexicon/general_citation_headings.php'))
  end
  let(:person) { lex_file.lex_entry.lex_item }

  let!(:monograph) { add_general_citation('מונוגרפיה על המחברת', 1) }
  let!(:article_1) { add_general_citation('זרקור על דמות נעלמה', 2) }
  let!(:article_2) { add_general_citation('אנדרוגניות במצור', 3) }

  # Titles as an LLM parse of the fixture would have stored them, i.e. what the flat general list
  # looks like today for an entry migrated before LexCitationGroup existed.
  def add_general_citation(title, seqno)
    create(:lex_citation, person: person, title: title, seqno: seqno, subject: nil, person_work: nil)
  end

  it 'files each general citation under the sub-heading it sat under in the legacy file' do
    expect(call).to have_attributes(grouped_count: 3, unmatched_count: 0, groups: %w(ספרים מאמרים))

    expect(monograph.reload.citation_group.title).to eq('ספרים')
    expect(article_1.reload.citation_group.title).to eq('מאמרים')
    expect(article_2.reload.citation_group.title).to eq('מאמרים')
  end

  it 'gives the sub-headings the order the legacy page had them in' do
    call
    expect(person.reload.citation_groups.map(&:title)).to eq(%w(ספרים מאמרים))
  end

  it 'numbers each sub-heading\'s citations from one' do
    call
    expect(person.reload.citation_groups.map { |g| g.citations.order(:seqno).map(&:seqno) }).to eq([[1], [1, 2]])
  end

  # The heading naming a work ('על ״שיחות אינטימיות״') is not a general sub-heading: its citations
  # belong under the work, and inventing a group for it would be worse than leaving them flat.
  it 'ignores headings that are not recognized general categories' do
    review = add_general_citation('ביקורת על הספר', 4)
    call
    expect(review.reload.citation_group).to be_nil
  end

  it 'leaves a citation that matches no source item in the ungrouped general list' do
    stray = add_general_citation('מאמר שאינו מופיע במקור כלל', 5)
    expect(call).to have_attributes(grouped_count: 3, unmatched_count: 1)
    expect(stray.reload.citation_group).to be_nil
  end

  describe 'what it refuses to touch' do
    it 'leaves citations already under a sub-heading alone' do
      group = create(:lex_citation_group, person: person, title: 'ביבליוגרפיה')
      monograph.update!(citation_group: group)

      call
      expect(monograph.reload.citation_group).to eq(group)
    end

    it 'leaves citations about a work alone' do
      work = create(:lex_person_work, person: person, title: 'שיחות אינטימיות')
      article_1.update!(person_work: work)

      call
      expect(article_1.reload.citation_group).to be_nil
      expect(article_1.person_work).to eq(work)
    end

    it 'leaves citations still carrying an unresolved legacy subject alone' do
      article_1.update!(subject: 'על משהו אחר')

      call
      expect(article_1.reload.citation_group).to be_nil
      expect(article_1.subject).to eq('על משהו אחר')
    end
  end

  it 'is safe to run twice' do
    call
    expect { described_class.call(person.reload) }.not_to change(LexCitationGroup, :count)
  end

  context 'when the legacy file is not readable' do
    before { lex_file.update!(full_path: '/nonexistent/00000.php') }

    it 'reports the entry as skipped and changes nothing' do
      expect(call).to have_attributes(skipped: :no_legacy_file, skipped?: true)
      expect(monograph.reload.citation_group).to be_nil
    end
  end

  context 'when the legacy file has no recognized general sub-heading' do
    before do
      lex_file.update!(full_path: Rails.root.join('spec/fixtures/files/lexicon/ul_directly_after_citations_header.php'))
    end

    it 'reports the entry as skipped' do
      expect(call).to have_attributes(skipped: :no_headings_in_source)
    end
  end
end
