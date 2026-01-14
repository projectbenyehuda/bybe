# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/publications' do
  before do
    login_as_lexicon_editor
  end

  let(:lex_publication) { create(:lex_entry, :publication).lex_item }

  let(:valid_publication_attributes) { attributes_for(:lex_publication).except('created_at', 'updated_at', 'id') }

  let(:valid_attributes) do
    valid_publication_attributes.merge(entry_attributes: { title: 'Test (test)' })
  end

  let(:invalid_attributes) do
    valid_publication_attributes.merge(entry_attributes: { title: ' ' })
  end

  describe 'GET /new' do
    subject(:call) { get '/lex/publications/new' }

    it 'renders a successful response' do
      expect(call).to eq(200)
    end
  end

  describe 'POST /create' do
    subject(:call) { post '/lex/publications', params: { lex_publication: attributes }, xhr: true }

    context 'with valid parameters' do
      let(:attributes) { valid_attributes }

      it 'creates a new LexPublication and redirects to show page' do
        expect { call }.to change(LexPublication, :count).by(1).and change(LexEntry, :count).by(1)
        lex_publication = LexPublication.order(id: :desc).first
        expect(call).to eq(200)
        expect(lex_publication).to have_attributes(valid_publication_attributes)
        expect(lex_publication.entry).to have_attributes(
          title: 'Test (test)',
          status: 'draft',
          sort_title: 'Test test'
        )
        expect(flash.notice).to eq(I18n.t('lexicon.publications.create.success'))
      end
    end

    context 'with invalid parameters' do
      let(:attributes) { invalid_attributes }

      it 're-renders the new template' do
        expect { call }.not_to change(LexPublication, :count)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'GET /edit' do
    subject { get "/lex/publications/#{lex_publication.id}/edit" }

    it { is_expected.to eq(200) }
  end

  describe 'PATCH /update' do
    subject(:call) do
      patch "/lex/publications/#{lex_publication.id}", params: { lex_publication: valid_attributes }, xhr: true
    end

    it 'updates the record' do
      expect(call).to eq(200)
      expect(lex_publication.reload).to have_attributes(valid_publication_attributes)
      expect(lex_publication.entry).to have_attributes(
        title: 'Test (test)',
        sort_title: 'Test test'
      )
    end
  end
end
