# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manual Publication Creation', type: :request do
  let(:user) { create(:user, :bib_workshop) }
  let(:authority) { create(:authority, bib_done: false) }
  let!(:manual_bib_source) do
    BibSource.find_or_create_by!(title: 'manual_entry', source_type: :manual_entry, status: :enabled)
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe 'POST /publications with manual entry' do
    let(:valid_params) do
      {
        publication: {
          title: 'Manually Entered Publication',
          author_line: 'Manual Author',
          publisher_line: 'Manual Publisher',
          pub_year: '1945',
          language: 'Hebrew',
          notes: 'Manually entered notes',
          source_id: 'https://example.com/manual/123',
          callnum: 'Manual-Shelf-001',
          authority_id: authority.id,
          bib_source: 'manual_entry',
          status: 'todo'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new publication with manual_entry bib_source' do
        expect do
          post publications_path, params: valid_params, as: :js
        end.to change(Publication, :count).by(1)

        publication = Publication.last
        expect(publication.title).to eq('Manually Entered Publication')
        expect(publication.author_line).to eq('Manual Author')
        expect(publication.publisher_line).to eq('Manual Publisher')
        expect(publication.pub_year).to eq('1945')
        expect(publication.language).to eq('Hebrew')
        expect(publication.notes).to eq('Manually entered notes')
        expect(publication.authority_id).to eq(authority.id)
        expect(publication.bib_source).to eq(manual_bib_source)
        expect(publication.status).to eq('todo')
      end

      it 'creates a holding with the manual_entry bib_source' do
        expect do
          post publications_path, params: valid_params, as: :js
        end.to change(Holding, :count).by(1)

        holding = Holding.last
        expect(holding.bib_source).to eq(manual_bib_source)
        expect(holding.location).to eq('Manual-Shelf-001')
        expect(holding.status).to eq('todo')
      end

      it 'returns a successful response' do
        post publications_path, params: valid_params, as: :js
        # JS format should return 200, but might redirect in some cases
        expect(response).to have_http_status(:success).or have_http_status(:redirect)
      end
    end

    context 'with minimal required fields only' do
      let(:minimal_params) do
        {
          publication: {
            title: 'Minimal Publication',
            author_line: 'Minimal Author',
            publisher_line: 'Minimal Publisher',
            pub_year: '1950',
            authority_id: authority.id,
            bib_source: 'manual_entry',
            status: 'todo'
          }
        }
      end

      it 'creates a publication with only required fields' do
        expect do
          post publications_path, params: minimal_params, as: :js
        end.to change(Publication, :count).by(1)

        publication = Publication.last
        expect(publication.title).to eq('Minimal Publication')
        expect(publication.language).to be_nil
        expect(publication.notes).to be_nil
      end
    end
  end

  describe 'manual_entry bib_source behavior' do
    it 'sets holding status to todo for manual_entry source_type' do
      params = {
        publication: {
          title: 'Test Publication',
          author_line: 'Test Author',
          publisher_line: 'Test Publisher',
          pub_year: '1960',
          authority_id: authority.id,
          bib_source: 'manual_entry',
          status: 'todo'
        }
      }

      post publications_path, params: params, as: :js

      holding = Holding.last
      expect(holding.status).to eq('todo')
    end

    it 'correctly identifies manual_entry as a source_type' do
      expect(manual_bib_source.source_type).to eq('manual_entry')
      expect(manual_bib_source.manual_entry?).to be true
    end
  end
end
