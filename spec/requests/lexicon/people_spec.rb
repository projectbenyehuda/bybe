# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/people' do
  before do
    login_as_lexicon_editor
  end

  let(:lex_person) { create(:lex_entry, :person).lex_item }
  let(:authority) { create(:authority) }

  let(:valid_person_attributes) do
    attributes_for(:lex_person).except(:created_at, :updated_at, :id, :works)
                               .merge(authority_id: authority.id)
  end

  let(:valid_attributes) do
    valid_person_attributes.merge(entry_attributes: { title: 'Test (test)' })
  end

  let(:invalid_attributes) do
    valid_person_attributes.merge(entry_attributes: { title: ' ' })
  end

  describe 'GET /new' do
    subject(:call) { get '/lex/people/new' }

    it 'renders a successful response' do
      expect(call).to eq(200)
    end
  end

  describe 'POST /create' do
    subject(:call) { post '/lex/people', params: { lex_person: attributes }, xhr: true }

    context 'with valid parameters' do
      let(:attributes) { valid_attributes }

      it 'creates a new LexPerson and redirects to show page' do
        expect { call }.to change(LexPerson, :count).by(1).and change(LexEntry, :count).by(1)
        lex_person = LexPerson.order(id: :desc).first
        expect(call).to eq(200)
        expect(lex_person).to have_attributes(valid_person_attributes)
        expect(lex_person.entry).to have_attributes(title: 'Test (test)', sort_title: 'תתתת_Test test')
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

  describe 'GET /edit' do
    subject { get "/lex/people/#{lex_person.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /update' do
    subject(:call) { patch "/lex/people/#{lex_person.id}", params: { lex_person: valid_attributes }, xhr: true }

    it 'updates the record' do
      expect(call).to eq(200)
      expect(lex_person.reload).to have_attributes(valid_person_attributes)
      expect(lex_person.entry).to have_attributes(title: 'Test (test)', sort_title: 'תתתת_Test test')
    end
  end
end
