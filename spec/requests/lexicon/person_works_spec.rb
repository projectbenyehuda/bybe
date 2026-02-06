# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/person_works' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }
  let(:authority) { create(:authority) }
  let(:publication) { create(:publication, authority: authority) }
  let(:collection) { create(:collection, publication: publication) }

  let!(:works) { create_list(:lex_person_work, 3, person: person) }

  let(:work) { works.first }

  describe 'GET /lexicon/people/:ID/works' do
    subject(:call) { get "/lex/people/#{person.id}/works" }

    it { is_expected.to eq(200) }
  end

  describe 'GET /lexicon/people/:ID/works/new' do
    subject(:call) { get "/lex/people/#{person.id}/works/new" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/people/:ID/works' do
    subject(:call) { post "/lex/people/#{person.id}/works", params: { lex_person_work: work_params }, xhr: true }

    context 'when valid params' do
      let(:work_params) { attributes_for(:lex_person_work).except(:person) }

      it 'creates new record' do
        expect { call }.to change { person.works.count }.by(1)
        expect(call).to eq(200)

        work = LexPersonWork.last
        expect(work).to have_attributes(work_params)
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
    subject(:call) { get "/lex/works/#{work.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /lex/works/:id' do
    subject(:call) { patch "/lex/works/#{work.id}", params: { lex_person_work: work_params }, xhr: true }

    context 'when valid params' do
      let(:work_params) { attributes_for(:lex_person_work).except(:person) }

      it 'updates record' do
        expect(call).to eq(200)
        expect(work.reload).to have_attributes(work_params)
      end
    end

    context 'when invalid params' do
      let(:work_params) { attributes_for(:lex_person_work, title: '') }

      it 're-renders edit form' do
        expect(call).to eq(422)
        expect(call).to render_template(:edit)
      end
    end

    context 'when updating with publication and collection' do
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
  end

  describe 'DELETE /lex/works/:id' do
    subject(:call) { delete "/lex/works/#{work.id}", xhr: true }

    it 'removes record' do
      expect { call }.to change { person.works.count }.by(-1)
      expect(call).to eq(200)
    end
  end

  describe 'POST /lex/works/:id/reorder' do
    subject(:call) do
      post "/lex/works/#{work_to_move.id}/reorder",
           params: { work_id: work_to_move.id, new_pos: 3, old_pos: 1 },
           xhr: true
    end

    let!(:works_same_type) do
      # Create works with the same work_type
      create_list(:lex_person_work, 4, person: person, work_type: 'original')
    end

    let(:work_to_move) { works_same_type[0] }

    it 'reorders the work' do
      # Store initial order
      works_same_type.map { |w| [w.id, w.seqno] }

      expect(call).to eq(200)

      # Verify work was moved to new position
      reordered_works = person.works.where(work_type: 'original').order(:seqno)
      expect(reordered_works[2].id).to eq(work_to_move.id)

      # Verify all seqno values are sequential starting from 1
      seqnos = reordered_works.pluck(:seqno)
      expect(seqnos).to eq((1..reordered_works.count).to_a)
    end

    it 'maintains separate ordering per work_type' do
      # Create works of different type
      other_type_work = create(:lex_person_work, person: person, work_type: 'translated', seqno: 1)

      original_seqno = other_type_work.seqno

      call

      # Verify work of different type was not affected
      expect(other_type_work.reload.seqno).to eq(original_seqno)
    end
  end

  describe 'seqno assignment' do
    # Create a separate person for these tests to avoid interference from global setup
    let(:test_person) { create(:lex_entry, :person).lex_item }

    context 'when creating a new work' do
      it 'automatically assigns seqno' do
        work_params = attributes_for(:lex_person_work, work_type: 'original').except(:person, :seqno)

        post "/lex/people/#{test_person.id}/works", params: { lex_person_work: work_params }, xhr: true

        new_work = LexPersonWork.last
        expect(new_work.seqno).to be_present
        expect(new_work.seqno).to be > 0
      end

      it 'assigns sequential seqno values' do
        # Create first work
        work1 = create(:lex_person_work, person: test_person, work_type: 'original')

        # Create second work with same type
        work_params = attributes_for(:lex_person_work, work_type: 'original').except(:person, :seqno)
        post "/lex/people/#{test_person.id}/works", params: { lex_person_work: work_params }, xhr: true

        work2 = LexPersonWork.last
        expect(work2.seqno).to eq(work1.seqno + 1)
      end

      it 'maintains separate seqno sequences per work_type' do
        # Create works of type 'original'
        create(:lex_person_work, person: test_person, work_type: 'original')
        create(:lex_person_work, person: test_person, work_type: 'original')

        # Create first work of type 'translated' - should start from 1
        work_params = attributes_for(:lex_person_work, work_type: 'translated').except(:person, :seqno)
        post "/lex/people/#{test_person.id}/works", params: { lex_person_work: work_params }, xhr: true

        translated_work = LexPersonWork.last
        expect(translated_work.work_type).to eq('translated')
        expect(translated_work.seqno).to eq(1) # Should start from 1 for new work_type

        # Verify original works still have their sequence
        original_works = test_person.works.where(work_type: 'original').order(:seqno)
        expect(original_works.pluck(:seqno)).to eq([1, 2])
      end
    end
  end
end
