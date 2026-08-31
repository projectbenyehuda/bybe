# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::MatchCitationSubjects do
  subject(:proposals) { described_class.call(person) }

  let(:person) { create(:lex_entry, :person).lex_item }

  def add_work(title)
    create(:lex_person_work, person: person, title: title)
  end

  def add_citation(subject)
    create(:lex_citation, person: person, subject: subject)
  end

  def proposal_for(subject)
    proposals.find { |proposal| proposal.subject == subject }
  end

  describe 'exact heading' do
    before do
      add_work('שונא הנסים')
      add_citation('שונא הנסים')
    end

    it 'proposes the work with certainty' do
      expect(proposal_for('שונא הנסים')).to have_attributes(work: person.works.first, similarity: 100,
                                                            certain?: true, generic: nil)
    end
  end

  describe 'the "על" prefix and a catalogue subtitle' do
    before do
      add_work('אור פרא : שירים')
      add_citation('על "אור פרא"')
    end

    it 'proposes the work with certainty, ignoring the prefix, the quotes and the subtitle' do
      expect(proposal_for('על "אור פרא"')).to have_attributes(work: person.works.first, similarity: 100,
                                                              certain?: true)
    end
  end

  describe 'a work whose own title starts with "על"' do
    before do
      add_work('על משכבם בלילות')
      add_citation('על משכבם בלילות')
    end

    it 'proposes it with certainty, rather than stripping part of its title as a prefix' do
      expect(proposal_for('על משכבם בלילות')).to have_attributes(work: person.works.first, similarity: 100,
                                                                 certain?: true)
    end
  end

  describe 'a heading only approximately naming a work' do
    before do
      add_work('אישה בגן')
      add_citation('על "אשה בגן"')
    end

    it 'proposes the work, but not with certainty' do
      proposal = proposal_for('על "אשה בגן"')
      expect(proposal.work).to eq person.works.first
      expect(proposal.similarity).to be_between(Lexicon::TitleSimilarity::MATCH_THRESHOLD, 99)
      expect(proposal).not_to be_certain
    end
  end

  describe 'a heading crediting the translated work’s own author' do
    # 00104.php's headings, e.g. 'על "הכומר מטור" לאונורה דה בלזאק'. The credit is not part of
    # the title, and used to drag the score below the threshold, leaving the heading unresolved.
    let(:subject_heading) { 'על "הכומר מטור" לאונורה דה בלזאק' }

    before do
      add_work('הכומר מטור / אונורה דה בלזאק ; אחרית דבר, אלישבע רוזן')
      add_citation(subject_heading)
    end

    it 'proposes the work with certainty, matching on the quoted title alone' do
      expect(proposal_for(subject_heading)).to have_attributes(work: person.works.first, similarity: 100,
                                                               certain?: true)
    end
  end

  describe 'a heading whose quoted title contains a gershayim of its own' do
    let(:subject_heading) { 'על "69.99 ש"ח" לפרדריק בגבדה' }

    before do
      add_work('69.99 ש"ח : רומן / פרדריק בגבדה')
      add_citation(subject_heading)
    end

    it 'takes the outermost pair of quotes as the title, not the innermost' do
      expect(proposal_for(subject_heading)).to have_attributes(work: person.works.first, similarity: 100,
                                                               certain?: true)
    end
  end

  describe 'a generic bucket heading' do
    before do
      add_work('שונא הנסים')
      add_citation('מאמרים')
    end

    it 'proposes keeping it as a general sub-heading, with certainty' do
      expect(proposal_for('מאמרים')).to have_attributes(generic: true, work: nil, certain?: true,
                                                        proposed?: true, heading_title: 'מאמרים')
    end

    it 'applies as a sub-heading of the general citations' do
      proposal_for('מאמרים').apply!(person)
      group = person.citation_groups.sole
      expect(group.title).to eq('מאמרים')
      expect(group.citations.count).to eq(1)
    end
  end

  # About half the legacy files write the heading with a trailing colon; it is layout punctuation,
  # not part of the name, and used to keep the heading from being recognized as generic at all.
  describe 'a generic bucket heading written with a trailing colon' do
    before do
      add_citation('ספרים:')
    end

    it 'is recognized, and drops the colon from the sub-heading name' do
      expect(proposal_for('ספרים:')).to have_attributes(generic: true, certain?: true, heading_title: 'ספרים')
    end
  end

  describe 'the general categories beyond ספרים and מאמרים' do
    before do
      add_citation('ספרי יובל')
      add_citation('ביבליוגרפיה:')
    end

    it 'recognizes them too' do
      expect(proposal_for('ספרי יובל')).to have_attributes(generic: true, heading_title: 'ספרי יובל')
      expect(proposal_for('ביבליוגרפיה:')).to have_attributes(generic: true, heading_title: 'ביבליוגרפיה')
    end
  end

  describe 'a heading naming no work of this person' do
    before do
      add_work('שונא הנסים')
      add_citation('רשימות מבית המרזח')
    end

    it 'is left unresolved' do
      expect(proposal_for('רשימות מבית המרזח')).to have_attributes(work: nil, similarity: nil,
                                                                   generic: nil, proposed?: false)
    end
  end

  describe 'a heading fitting two works equally well' do
    before do
      add_work('צורות : שירים')
      add_work('צורות : סיפורים')
      add_citation('על "צורות"')
    end

    it 'is reported as ambiguous rather than guessed at' do
      expect(proposal_for('על "צורות"')).to have_attributes(work: nil, ambiguous: true, certain?: false)
    end
  end

  it 'groups every citation under a heading into one proposal' do
    add_work('שונא הנסים')
    citations = Array.new(3) { add_citation('שונא הנסים') }

    expect(proposal_for('שונא הנסים').citations).to match_array(citations)
  end

  it 'ignores citations already linked to a work' do
    work = add_work('שונא הנסים')
    create(:lex_citation, person: person, person_work: work, subject: nil)

    expect(proposals).to be_empty
  end
end
