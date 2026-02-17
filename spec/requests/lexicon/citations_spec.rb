# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/citations' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }

  let!(:citations) { create_list(:lex_citation, 3, person: person) }

  let(:citation) { citations.first }

  describe 'GET /lexicon/people/:ID/citations' do
    subject(:call) { get "/lex/people/#{person.id}/citations" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/people/:ID/citations/new' do
    subject(:call) { get "/lex/people/#{person.id}/citations/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/people/:ID/citations' do
    subject(:call) { post "/lex/people/#{person.id}/citations", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation).except(:authors, :seqno) }

      it 'creates new record' do
        expect { call }.to change { person.citations.count }.by(1)
        expect(call).to eq(200)

        citation = LexCitation.last
        expect(citation).to have_attributes(citation_params)
        expect(citation.seqno).to be_present
      end

      context 'when creating with person_work' do
        let(:work) { create(:lex_person_work, person: person, title: 'Some Work') }
        let!(:existing_citation) { create(:lex_citation, person: person, person_work: work, seqno: 2) }
        let(:citation_params) do
          attributes_for(:lex_citation).except(:authors, :seqno).merge(lex_person_work_id: work.id)
        end

        it 'adds citation to the bottom of subject_title group' do
          expect { call }.to change { person.citations.count }.by(1)
          expect(call).to eq(200)

          citation = LexCitation.last
          expect(citation.lex_person_work_id).to eq(work.id)
          expect(citation.seqno).to eq(3) # max seqno (2) + 1
        end
      end

      context 'when creating with subject string' do
        let!(:existing_citation) { create(:lex_citation, person: person, subject: 'Test Subject', seqno: 5) }
        let(:citation_params) do
          attributes_for(:lex_citation).except(:authors, :seqno, :lex_person_work_id)
                                       .merge(subject: 'Test Subject', lex_person_work_id: nil)
        end

        it 'adds citation to the bottom of subject_title group' do
          expect { call }.to change { person.citations.count }.by(1)
          expect(call).to eq(200)

          citation = LexCitation.last
          expect(citation.subject).to eq('Test Subject')
          expect(citation.seqno).to eq(6) # max seqno (5) + 1
        end
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '').except(:seqno) }

      it 're-renders edit form' do
        expect { call }.not_to(change { person.citations.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /lexicon/citations/:id/edit' do
    subject(:call) { get "/lex/citations/#{citation.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/citations/:id' do
    subject(:call) { patch "/lex/citations/#{citation.id}", params: { lex_citation: citation_params }, xhr: true }

    context 'when valid params' do
      let(:citation_params) { attributes_for(:lex_citation).except(:authors, :seqno) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(citation.reload).to have_attributes(citation_params)
      end
    end

    context 'when invalid params' do
      let(:citation_params) { attributes_for(:lex_citation, title: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when subject_title is changed' do
      let!(:work1) { create(:lex_person_work, person: person, title: 'Work A') }
      let!(:work2) { create(:lex_person_work, person: person, title: 'Work B') }

      let!(:citation1) { create(:lex_citation, person: person, person_work: work1, seqno: 1) }
      let!(:citation2) { create(:lex_citation, person: person, person_work: work1, seqno: 2) }
      let!(:citation3) { create(:lex_citation, person: person, person_work: work2, seqno: 3) }

      let(:citation) { citation1 }

      context 'when changing person_work to an existing work' do
        let(:citation_params) { { lex_person_work_id: work2.id } }

        it 'adds citation to the bottom of the new subject_title list' do
          expect(call).to eq(200)
          expect(citation.reload).to have_attributes(lex_person_work_id: work2.id, seqno: 4)
        end
      end

      context 'when changing to a new subject string' do
        let(:citation_params) { { subject: 'New Subject', lex_person_work_id: nil } }

        it 'sets seqno to 1' do
          expect(call).to eq(200)
          citation.reload
          expect(citation.subject).to eq('New Subject')
          expect(citation.lex_person_work_id).to be_nil
          expect(citation.seqno).to eq(1)
        end
      end
    end
  end

  describe 'DELETE /lex/citations/:id' do
    subject(:call) { delete "/lex/citations/#{citation.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { person.citations.count }.by(-1)
      expect(call).to eq(200)
    end
  end

  describe 'POST /lex/citations/:id/reorder' do
    subject(:call) do
      post "/lex/citations/#{citation_to_move.id}/reorder",
           params: { new_index: new_index, old_index: old_index, subject_title: subject_title },
           xhr: true
    end

    let(:work) { create(:lex_person_work, person: person, title: 'Test Work') }
    let(:subject_title) { work.title }

    let!(:citation_1) { create(:lex_citation, person: person, person_work: work, seqno: 2) }
    let!(:citation_2) { create(:lex_citation, person: person, person_work: work, seqno: 3) }
    let!(:citation_3) { create(:lex_citation, person: person, person_work: work, seqno: 5) }
    let!(:citation_4) { create(:lex_citation, person: person, person_work: work, seqno: 6) }
    let!(:other_work) { create(:lex_person_work, person: person, title: 'Other Work') }
    let!(:other_citation) { create(:lex_citation, person: person, person_work: other_work, seqno: 1) }

    let(:reordered_citations) { person.reload.citations.where(lex_person_work_id: work.id).order(:seqno) }

    context 'when we move item forward' do
      let(:citation_to_move) { citation_1 }
      let(:old_index) { 0 }
      let(:new_index) { 3 }

      it 'reorders citations and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_citations.map(&:id)).to eq([citation_2.id, citation_3.id, citation_4.id, citation_1.id])
        expect(reordered_citations.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when we move item backward' do
      let(:citation_to_move) { citation_3 }
      let(:old_index) { 2 }
      let(:new_index) { 1 }

      it 'reorders citations and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_citations.map(&:id)).to eq([citation_1.id, citation_3.id, citation_2.id, citation_4.id])
        expect(reordered_citations.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when old_index does not match' do
      let(:old_index) { 1 }
      let(:new_index) { 2 }
      let(:citation_to_move) { citation_3 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq('old_index mismatch, actual: 2, got: 1')
      end
    end

    context 'when subject_title does not match' do
      let(:citation_to_move) { other_citation }
      let(:old_index) { 0 }
      let(:new_index) { 1 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq("subject_title mismatch, actual: '#{other_work.title}', got: '#{work.title}'")
      end
    end

    context 'when using subject string instead of person_work' do
      let(:subject_title) { 'Subject String' }

      let!(:citation_1) { create(:lex_citation, person: person, subject: subject_title, seqno: 1) }
      let!(:citation_2) { create(:lex_citation, person: person, subject: subject_title, seqno: 2) }
      let!(:citation_3) { create(:lex_citation, person: person, subject: subject_title, seqno: 3) }

      let(:citation_to_move) { citation_1 }
      let(:old_index) { 0 }
      let(:new_index) { 2 }

      it 'reorders citations correctly' do
        expect(call).to eq(200)

        reordered = person.reload.citations.select { |c| c.subject == subject_title }.sort_by(&:seqno)
        expect(reordered.map(&:id)).to eq([citation_2.id, citation_3.id, citation_1.id])
        expect(reordered.map(&:seqno)).to eq((1..3).to_a)
      end
    end
  end
end
