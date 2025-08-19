# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/people' do
  let(:lex_person) { create(:lex_entry, :person, status: :migrated).lex_item }
  let(:authority) { create(:authority) }

  let(:valid_person_attributes) do
    attributes_for(:lex_person).except('created_at', 'updated_at', 'id').merge(authority_id: authority.id)
  end

  let(:valid_attributes) do
    valid_person_attributes.merge(entry_attributes: { title: 'Test (test)' })
  end

  let(:invalid_attributes) do
    valid_person_attributes.merge(entry_attributes: { title: ' ' })
  end

  describe 'GET /new' do
    subject(:call) { get '/lexicon/people/new' }

    it 'renders a successful response' do
      expect(call).to eq(200)
    end
  end

  describe 'POST /create' do
    subject(:call) { post '/lexicon/people', params: { lex_person: attributes } }

    context 'with valid parameters' do
      let(:attributes) { valid_attributes }

      it 'creates a new LexPerson and redirects to show page' do
        expect { call }.to change(LexPerson, :count).by(1).and change(LexEntry, :count).by(1)
        lex_person = LexPerson.order(id: :desc).first
        expect(call).to redirect_to lexicon_person_path(lex_person)
        expect(lex_person).to have_attributes(valid_person_attributes)
        expect(lex_person.entry).to have_attributes(title: 'Test (test)', status: 'manual', sort_title: 'Test test')
        expect(flash.notice).to eq(I18n.t('lexicon.people.create.success'))
      end
    end

    context 'with invalid parameters' do
      let(:attributes) { invalid_attributes }

      it 're-renders the new template' do
        expect { call }.not_to change(LexPerson, :count)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /index' do
    subject { get '/lexicon/people' }

    before do
      create_list(:lex_person, 5)
    end

    it { is_expected.to eq(200) }
  end

  describe 'GET /show' do
    subject { get "/lexicon/people/#{lex_person.id}" }

    it { is_expected.to eq(200) }

    context 'when lex person has linked authority' do
      before do
        lex_person.update!(authority_id: authority.id)
      end

      it { is_expected.to eq(200) }
    end
  end

  describe 'GET /edit' do
    subject { get "/lexicon/people/#{lex_person.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /update' do
    subject(:call) { patch "/lexicon/people/#{lex_person.id}", params: { lex_person: valid_attributes } }

    it 'updates the record' do
      expect(call).to redirect_to lexicon_person_path(lex_person)
      expect(lex_person.reload).to have_attributes(valid_person_attributes)
      expect(lex_person.entry).to have_attributes(title: 'Test (test)', status: 'migrated', sort_title: 'Test test')
      expect(flash.notice).to eq(I18n.t('lexicon.people.update.success'))
    end
  end

  describe 'DELETE /destroy' do
    subject(:call) { delete "/lexicon/people/#{lex_person.id}" }

    before do
      lex_person
    end

    it 'destroys the requested lexicon person' do
      expect { call }.to change(LexPerson, :count).by(-1).and change(LexEntry, :count).by(-1)
      expect(call).to redirect_to lexicon_people_path
      expect(flash.alert).to eq(I18n.t('lexicon.people.destroy.success'))
    end
  end
end
