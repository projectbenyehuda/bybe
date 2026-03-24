# frozen_string_literal: true

require 'rails_helper'

describe IngestibleTextsController do
  include_context 'when editor logged in', :edit_catalog

  let!(:ingestible) { create(:ingestible, :with_buffers) }

  describe '#update saves to cache' do
    subject(:call) do
      patch :update, params: { ingestible_id: ingestible.id, id: 2,
                               ingestible_text: { title: 'Updated Title', content: 'Updated Content' } }
    end

    it 'persists the text version to the textarea cache' do
      call
      ingestible.reload
      cache = ingestible.parsed_textarea_cache
      expect(cache).not_to be_empty
      expect(cache.first['title']).to eq('Updated Title')
      expect(cache.first['content']).to eq('Updated Content')
    end
  end

  describe '#save_to_cache' do
    subject(:call) do
      post :save_to_cache, params: { ingestible_id: ingestible.id, id: 0,
                                     title: 'Cached Title', content: 'Cached Content' }
    end

    it 'returns HTTP 200' do
      expect(call).to have_http_status(:ok)
    end

    it 'saves the version to the ingestible textarea cache' do
      call
      ingestible.reload
      cache = ingestible.parsed_textarea_cache
      expect(cache).not_to be_empty
      expect(cache.first['title']).to eq('Cached Title')
      expect(cache.first['content']).to eq('Cached Content')
    end

    context 'when the same content is sent twice' do
      it 'only stores one version (no duplicates)' do
        2.times { post :save_to_cache, params: { ingestible_id: ingestible.id, id: 0,
                                                 title: 'Same', content: 'Same Content' } }
        ingestible.reload
        same_versions = ingestible.parsed_textarea_cache.select { |v| v['title'] == 'Same' }
        expect(same_versions.length).to eq(1)
      end
    end
  end

  describe '#fetch_cached_version' do
    before do
      ingestible.save_text_to_cache('First', 'First content')
      ingestible.save_text_to_cache('Second', 'Second content')
    end

    it 'returns the content for the given cache index' do
      get :fetch_cached_version, params: { ingestible_id: ingestible.id, id: 0, cache_index: 0 }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['content']).to eq('First content')
    end

    it 'returns the correct content for a later index' do
      get :fetch_cached_version, params: { ingestible_id: ingestible.id, id: 0, cache_index: 1 }
      expect(JSON.parse(response.body)['content']).to eq('Second content')
    end

    it 'returns 404 for an out-of-range index' do
      get :fetch_cached_version, params: { ingestible_id: ingestible.id, id: 0, cache_index: 99 }
      expect(response).to have_http_status(:not_found)
    end
  end
end
