# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/person_works' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }

  describe 'GET /lexicon/people/:ID/works' do
    subject(:call) { get "/lex/people/#{person.id}/works" }

    let!(:works) { create_list(:lex_person_work, 3, person: person) }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/people/:ID/works/new' do
    subject(:call) { get "/lex/people/#{person.id}/works/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/people/:ID/works' do
    subject(:call) { post "/lex/people/#{person.id}/works", params: { lex_person_work: work_params }, xhr: true }

    context 'when valid params' do
      let(:work_params) { attributes_for(:lex_person_work).except(:person, :seqno) }

      it 'creates new record' do
        expect { call }.to change { person.works.count }.by(1)
        expect(call).to eq(200)

        work = LexPersonWork.last
        expect(work).to have_attributes(work_params)
        expect(work.seqno).to be_present
      end
    end

    context 'when invalid params' do
      let(:work_params) { attributes_for(:lex_person_work, title: '') }

      it 're-renders new form' do
        expect { call }.not_to(change { person.works.count })
        expect(call).to eq(422)
        expect(call).to render_template(:new)
      end
    end

    context 'when creating with publication and collection' do
      let(:authority) { create(:authority) }
      let(:publication) { create(:publication, authority: authority) }
      let(:collection) { create(:collection, publication: publication) }

      let(:work_params) do
        attributes_for(:lex_person_work).except(:person).merge(
          publication_id: publication.id,
          collection_id: collection.id
        )
      end

      before do
        person.update(authority: authority)
      end

      it 'creates work with publication and collection associations' do
        expect { call }.to change { person.works.count }.by(1)
        expect(call).to eq(200)

        work = LexPersonWork.last
        expect(work.publication).to eq(publication)
        expect(work.collection).to eq(collection)
      end
    end
  end

  describe 'GET /lexicon/works/:id/edit' do
    let!(:works) { create_list(:lex_person_work, 3, person: person) }
    let(:work) { works.first }

    subject(:call) { get "/lex/works/#{work.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/works/:id' do
    subject(:call) { patch "/lex/works/#{work.id}", params: { lex_person_work: work_params }, xhr: true }

    let(:work) { create(:lex_person_work, person: person) }

    context 'when valid params' do
      let(:work_params) { attributes_for(:lex_person_work).except(:person, :seqno) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(work.reload).to have_attributes(work_params)
      end
    end

    context 'when invalid params' do
      let(:work_params) { attributes_for(:lex_person_work, title: '').except(:person, :seqno) }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when updating with publication and collection' do
      let(:authority) { create(:authority) }
      let(:publication) { create(:publication, authority: authority) }
      let(:collection) { create(:collection, publication: publication) }

      let(:work_params) do
        {
          publication_id: publication.id,
          collection_id: collection.id
        }
      end

      before do
        person.update(authority: authority)
      end

      it 'updates work with publication and collection associations' do
        expect(call).to eq(200)

        work.reload
        expect(work.publication).to eq(publication)
        expect(work.collection).to eq(collection)
      end
    end

    context 'when work_type is changed' do
      let!(:works) do
        [
          create(:lex_person_work, person: person, work_type: 'original', seqno: 2),
          create(:lex_person_work, person: person, work_type: 'original', seqno: 1),
          create(:lex_person_work, person: person, work_type: 'translated', seqno: 4)
        ]
      end

      let(:work) { works.first }

      let(:work_params) do
        attributes_for(:lex_person_work).except(:person, :seqno, :work_type).merge(work_type: new_work_type)
      end

      context 'when we have works with a new work_type' do
        let(:new_work_type) { 'translated' }

        it 'adds item to the bottom of the new work_type list' do
          expect(call).to eq(200)
          expect(work.reload).to have_attributes(work_type: 'translated', seqno: 5)
        end
      end

      context 'when we have no works with a new work_type' do
        let(:new_work_type) { 'edited' }

        it 'sets seqno to 1' do
          expect(call).to eq(200)
          expect(work.reload).to have_attributes(work_type: 'edited', seqno: 1)
        end
      end
    end
  end

  describe 'DELETE /lex/works/:id' do
    subject(:call) { delete "/lex/works/#{work.id}", xhr: true }

    let!(:works) { create_list(:lex_person_work, 3, person: person) }
    let(:work) { works.first }

    it 'removes record' do
      expect { call }.to change { person.works.count }.by(-1)
      expect(call).to eq(200)
    end
  end

  describe 'POST /lex/works/:id/reorder' do
    subject(:call) do
      post "/lex/works/#{work_to_move.id}/reorder",
           params: { new_index: new_index, old_index: old_index, work_type: work_type },
           xhr: true
    end

    let(:work_type) { 'original' }

    let!(:work_1) { create(:lex_person_work, person: person, work_type: work_type, seqno: 2) }
    let!(:work_2) { create(:lex_person_work, person: person, work_type: work_type, seqno: 3) }
    let!(:work_3) { create(:lex_person_work, person: person, work_type: work_type, seqno: 5) }
    let!(:work_4) { create(:lex_person_work, person: person, work_type: work_type, seqno: 6) }
    let!(:translated_work) { create(:lex_person_work, person: person, work_type: 'translated', seqno: 1) }

    let(:reordered_works) { person.reload.works.where(work_type: work_type).order(:seqno) }

    context 'when we move item forward' do
      let(:work_to_move) { work_1 }
      let(:old_index) { 0 }
      let(:new_index) { 3 }

      it 'reorders works and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_works.map(&:id)).to eq([work_2.id, work_3.id, work_4.id, work_1.id])
        expect(reordered_works.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when we move item backward' do
      let(:work_to_move) { work_3 }
      let(:old_index) { 2 }
      let(:new_index) { 1 }

      it 'reorders works and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_works.map(&:id)).to eq([work_1.id, work_3.id, work_2.id, work_4.id])
        expect(reordered_works.map(&:seqno)).to eq((1..4).to_a)
      end
    end

    context 'when old_index does not match' do
      let(:old_index) { 1 }
      let(:new_index) { 2 }
      let(:work_to_move) { work_3 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq('old_index mismatch, actual: 2, got: 1')
      end
    end

    context 'when work_type does not match' do
      let(:work_to_move) { translated_work }
      let(:old_index) { 1 }
      let(:new_index) { 2 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq("work_type mismatch, actual: 'translated', got: 'original'")
      end
    end
  end
end
