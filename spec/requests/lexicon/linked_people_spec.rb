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
      let(:attrs) { attributes_for(:lex_linked_person).except(:person_work) }

      it 'creates a new linked person for the work' do
        expect { call }.to change(LexLinkedPerson, :count).by(1)
        expect(response).to have_http_status(:ok)

        created = LexLinkedPerson.order(id: :desc).first
        expect(created).to have_attributes(attrs)
        expect(created.person_work).to eq(work)
      end
    end

    context 'with valid person entry params' do
      let(:person_entry) { create(:lex_entry, :person) }
      let(:attrs) do
        {
          name: person_entry.title,
          person_lex_entry_id: person_entry.id,
          link_type: 'editor'
        }
      end

      it 'creates record linked to LexEntry' do
        expect { call }.to change(LexLinkedPerson, :count).by(1)
        expect(response).to have_http_status(:ok)

        created = LexLinkedPerson.order(id: :desc).first
        expect(created.person_entry).to eq(person_entry)
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
end
