# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/linked_people' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }
  let!(:work) { create(:lex_person_work, person: person) }
  let(:linked_person) { work.linked_people.first }

  describe 'GET /lex/works/:work_id/linked_people' do
    subject(:call) { get "/lex/works/#{work.id}/linked_people" }

    let!(:linked_people) { create_list(:lex_linked_person, 3, person_work: work) }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lex/works/:work_id/linked_people' do
    subject(:call) { post "/lex/works/#{work.id}/linked_people", params: { lex_linked_person: attrs }, xhr: true }

    context 'with valid params' do
      let(:attrs) { attributes_for(:lex_linked_person).except(:person_work, :seqno) }

      context 'when there are no existing linked people in the work' do
        it 'creates a new linked person for the work and sets seqno to 1' do
          expect { call }.to change(LexLinkedPerson, :count).by(1)
          expect(response).to have_http_status(:ok)

          created = LexLinkedPerson.order(id: :desc).first
          expect(created).to have_attributes(attrs)
          expect(created.person_work).to eq(work)
          expect(created.seqno).to eq(1)
        end
      end

      context 'when work already has linked people with seqno' do
        let!(:existing_1) { create(:lex_linked_person, person_work: work, seqno: 2) }
        let!(:existing_2) { create(:lex_linked_person, person_work: work, seqno: 5) }

        it 'assigns seqno as max seqno + 1' do
          expect { call }.to change(LexLinkedPerson, :count).by(1)
          expect(response).to have_http_status(:ok)

          created = LexLinkedPerson.order(id: :desc).first
          expect(created).to have_attributes(attrs)
          expect(created.person_work).to eq(work)
          expect(created.seqno).to eq(6)
        end
      end
    end

    context 'with invalid params' do
      let(:attrs) { { name: nil, link_type: 'author' } }

      it 'fails with Unprocessable Content status' do
        expect { call }.not_to(change(LexLinkedPerson, :count))
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE /lex/linked_people/:id' do
    subject(:call) { delete "/lex/linked_people/#{linked_person.id}", xhr: true }

    let!(:linked_person) { create(:lex_linked_person, person_work: work) }

    it 'destroys the requested linked person but keeps LexPersonWork record' do
      expect { call }.to change { work.linked_people.count }.by(-1)
      expect(call).to eq(200)
      expect { work.reload }.not_to raise_error
    end
  end

  describe 'POST /lex/linked_people/:id/reorder' do
    subject(:call) do
      post "/lex/linked_people/#{linked_person_to_move.id}/reorder",
           params: { new_index: new_index, old_index: old_index },
           xhr: true
    end

    let!(:linked_person_1) { create(:lex_linked_person, person_work: work, seqno: 2) }
    let!(:linked_person_2) { create(:lex_linked_person, person_work: work, seqno: 3) }
    let!(:linked_person_3) { create(:lex_linked_person, person_work: work, seqno: 5) }

    let(:reordered_linked_people) { work.reload.linked_people.sort_by(&:sort_value) }

    context 'when we move item forward' do
      let(:linked_person_to_move) { linked_person_1 }
      let(:old_index) { 0 }
      let(:new_index) { 2 }

      it 'reorders linked people and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_linked_people.map(&:id)).to eq(
          [linked_person_2.id, linked_person_3.id, linked_person_1.id]
        )
        expect(reordered_linked_people.map(&:seqno)).to eq((1..3).to_a)
      end
    end

    context 'when we move item backward' do
      let(:linked_person_to_move) { linked_person_2 }
      let(:old_index) { 1 }
      let(:new_index) { 0 }

      it 'reorders linked people and makes seqno sequential' do
        expect(call).to eq(200)

        expect(reordered_linked_people.map(&:id)).to eq(
          [linked_person_2.id, linked_person_1.id, linked_person_3.id]
        )
        expect(reordered_linked_people.map(&:seqno)).to eq((1..3).to_a)
      end
    end

    context 'when old_index does not match' do
      let(:linked_person_to_move) { linked_person_3 }
      let(:old_index) { 1 }
      let(:new_index) { 2 }

      it 'fails with bad request' do
        expect(call).to eq(400)
        expect(response.body).to eq('old_index mismatch, actual: 2, got: 1')
      end
    end
  end
end
