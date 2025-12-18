# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Noindex meta tags', type: :request do
  let!(:manifestation) do
    Chewy.strategy(:atomic) do
      create(:manifestation, status: :published, markdown: '## Test\n\nContent here.')
    end
  end

  let!(:collection) do
    create(:collection)
  end

  let!(:anthology) do
    create(:anthology, access: :pub)
  end

  let!(:authority) do
    create(:authority)
  end

  after do
    Chewy.massacre
  end

  describe 'read pages' do
    it 'does not include noindex meta tag on manifestation read page (/read/:id)' do
      get manifestation_path(manifestation)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('<meta name="robots" content="noindex">')
    end

    it 'includes noindex meta tag on manifestation readmode page (/read/:id/read)' do
      get manifestation_readmode_path(manifestation)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<meta name="robots" content="noindex">')
    end
  end

  describe 'print pages' do
    it 'includes noindex meta tag on manifestation print page' do
      get manifestation_print_path(manifestation)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<meta name="robots" content="noindex">')
    end

    it 'includes noindex meta tag on collection print page' do
      get collection_print_path(collection)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<meta name="robots" content="noindex">')
    end

    it 'includes noindex meta tag on anthology print page' do
      get anthology_print_path(anthology)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<meta name="robots" content="noindex">')
    end

    it 'includes noindex meta tag on authors print page' do
      get authors_print_path(id: authority.id)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('<meta name="robots" content="noindex">')
    end
  end

  describe 'regular pages without noindex' do
    it 'does not include noindex meta tag on collection show page' do
      get collection_path(collection)
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('<meta name="robots" content="noindex">')
    end
  end
end
