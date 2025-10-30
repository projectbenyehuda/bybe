# frozen_string_literal: true

require 'rails_helper'
require 'debug'

describe SearchController do
  include_context 'when editor logged in', :handle_proofs

  let(:authority) { create(:authority, name: 'Test Authority') }
  let(:manifestation) { create(:manifestation, title: 'Test Manifestation') }
  let(:collection) { create(:collection, collection_type: :volume, title: 'Test Collection') }
  let(:collection_by_authority) { create(:collection, collection_type: :periodical, authors: [authority]) }
  let(:dict) { create(:dictionary_entry, defhead: 'Test Dictionary Entry', manifestation: create(:manifestation)) }

  before do
    clean_tables
    Chewy.strategy(:atomic) do
      authority
      manifestation
      collection
      collection_by_authority
      dict

      # some data not matching search query
      create_list(:manifestation, 5)
      create_list(:collection, 5)
      create_list(:dictionary_entry, 5)
    end
  end

  describe '#results' do
    subject(:call) { get :results, params: { q: 'Test' } }

    it 'completes successfully' do
      expect(call).to be_successful

      expect(assigns(:total)).to eq 5

      expect(assigns(:results).map(&:class).map(&:name)).to eq %w(
        AuthoritiesIndex
        ManifestationsIndex
        CollectionsIndex
        CollectionsIndex
        DictIndex
      )

      expect(assigns(:results).map(&:id)).to eq(
        [authority.id, manifestation.id, collection.id, collection_by_authority.id, dict.id]
      )
    end

    context 'when filtering by manifestations only' do
      subject(:call) { get :results, params: { q: 'Test', index_types: ['manifestations'] } }

      it 'returns only manifestations' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(ManifestationsIndex)
        expect(assigns(:results).map(&:id)).to eq([manifestation.id])
      end
    end

    context 'when filtering by authorities only' do
      subject(:call) { get :results, params: { q: 'Test', index_types: ['authorities'] } }

      it 'returns only authorities' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(AuthoritiesIndex)
        expect(assigns(:results).map(&:id)).to eq([authority.id])
      end
    end

    context 'when filtering by dict only' do
      subject(:call) { get :results, params: { q: 'Test', index_types: ['dict'] } }

      it 'returns only dictionary entries' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(DictIndex)
        expect(assigns(:results).map(&:id)).to eq([dict.id])
      end
    end

    context 'when filtering by collections only' do
      subject(:call) { get :results, params: { q: 'Test', index_types: ['collections'] } }

      it 'returns only collections' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 2
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(CollectionsIndex CollectionsIndex)
        expect(assigns(:results).map(&:id)).to eq([collection.id, collection_by_authority.id])
      end
    end

    context 'when filtering by multiple types' do
      subject(:call) { get :results, params: { q: 'Test', index_types: %w[manifestations authorities] } }

      it 'returns only the selected types' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 2
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(AuthoritiesIndex ManifestationsIndex)
        expect(assigns(:results).map(&:id)).to eq([authority.id, manifestation.id])
      end
    end
  end
end
