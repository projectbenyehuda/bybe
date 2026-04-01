# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legacy URL routing', type: :request do
  let(:manifestation) { create(:manifestation, status: :published) }
  let(:authority) { create(:authority) }

  describe 'legacy file URL redirect' do
    context 'when LegacyUrl for a file path points to a Manifestation' do
      let!(:legacy_url) do
        LegacyUrl.create!(from_url: '/testdir/testfile.html', target: manifestation,
                          description: 'test')
      end

      it 'redirects to the manifestation read page' do
        get '/testdir/testfile.html'
        expect(response).to redirect_to(controller: :manifestation, action: :read, id: manifestation.id)
      end
    end

    context 'when LegacyUrl exists with no target' do
      let!(:legacy_url) do
        LegacyUrl.create!(from_url: '/testdir/orphan.html', description: 'orphan')
      end

      it 'returns not_found' do
        get '/testdir/orphan.html'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'legacy directory URL redirect' do
    context 'when LegacyUrl for a directory path points to an Authority' do
      let!(:legacy_url) do
        LegacyUrl.create!(from_url: '/authdir', target: authority, description: 'test')
      end

      it 'redirects to the author toc page' do
        get '/authdir'
        expect(response).to redirect_to(controller: :authors, action: :toc, id: authority.id)
      end
    end

    context 'when LegacyUrl for index.html path points to an Authority' do
      let!(:legacy_url) do
        LegacyUrl.create!(from_url: '/authdir2/index.html', target: authority, description: 'test')
      end

      it 'redirects to the author toc page' do
        get '/authdir2/index.html'
        expect(response).to redirect_to(controller: :authors, action: :toc, id: authority.id)
      end
    end
  end

  describe 'non-legacy URL' do
    it 'does not route to legacy handler' do
      get '/some/nonexistent/path'
      expect(response).not_to have_http_status(:redirect)
    end
  end
end
