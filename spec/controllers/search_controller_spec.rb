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
  let(:lex_entry) { create(:lex_entry, :person, status: :published, title: 'Test Lexicon Entry') }

  before do
    clean_tables
    Chewy.strategy(:atomic) do
      authority
      manifestation
      collection
      collection_by_authority
      dict
      lex_entry


      # some data not matching search query
      create_list(:manifestation, 2)
      create_list(:collection, 2)
      create_list(:dictionary_entry, 2)
      create_list(:lex_entry, 2, :person)
    end
  end

  describe '#results' do
    subject(:call) { get :results, params: { q: 'Test' } }

    it 'completes successfully' do
      expect(call).to be_successful

      expect(assigns(:total)).to eq 6

      expect(assigns(:results).map(&:class).map(&:name)).to eq %w(
        AuthoritiesIndex
        ManifestationsIndex
        CollectionsIndex
        CollectionsIndex
        DictIndex
        LexEntriesIndex
      )

      expect(assigns(:results).map(&:id)).to eq(
        [authority.id, manifestation.id, collection.id, collection_by_authority.id, dict.id, lex_entry.id]
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

    context 'when filtering by lexicon entries only' do
      subject(:call) { get :results, params: { q: 'Test', index_types: ['lex_entries'] } }

      it 'returns only lexicon entries' do
        expect(call).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(LexEntriesIndex)
        expect(assigns(:results).map(&:id)).to eq([lex_entry.id])
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

    context 'when filter is persisted in session' do
      it 'remembers the filter selection for subsequent searches' do
        # First search with manifestations filter
        get :results, params: { q: 'Test', index_types: ['manifestations'] }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(ManifestationsIndex)

        # Second search without filter parameter - should use session
        get :results, params: { q: 'Test' }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(ManifestationsIndex)
      end

      it 'allows changing the filter selection' do
        # First search with manifestations filter
        get :results, params: { q: 'Test', index_types: ['manifestations'] }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1

        # Second search with authorities filter - should override session
        get :results, params: { q: 'Test', index_types: ['authorities'] }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(AuthoritiesIndex)

        # Third search without filter parameter - should use new filter from session
        get :results, params: { q: 'Test' }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(AuthoritiesIndex)
      end

      it 'allows resetting to all types by unchecking all filters' do
        # First search with manifestations filter
        get :results, params: { q: 'Test', index_types: ['manifestations'] }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 1

        # Submit form with no checkboxes selected (simulating unchecking all)
        # Rails will send index_types as [''] from the hidden field
        get :results, params: { q: 'Test', index_types: [''] }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 6 # All types should be returned
        expect(assigns(:results).map(&:class).map(&:name)).to eq %w(
          AuthoritiesIndex
          ManifestationsIndex
          CollectionsIndex
          CollectionsIndex
          DictIndex
          LexEntriesIndex
        )

        # Subsequent search without params should use "all types" from session
        get :results, params: { q: 'Test' }
        expect(response).to be_successful
        expect(assigns(:total)).to eq 6
      end
    end
  end
end
