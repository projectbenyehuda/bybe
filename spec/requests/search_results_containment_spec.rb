# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search results containment', type: :request do
  let(:volume) do
    create(:collection, collection_type: :volume, title: 'Containing Volume', pub_year: '1923',
                        manifestations: [manifestation])
  end

  before do
    clean_tables
    Chewy.strategy(:atomic) do
      manifestation
      volume
    end
  end

  describe 'GET /search/results' do
    subject(:results) do
      get search_results_internal_path, params: { q: 'Test', index_types: ['manifestations'] }
      response.body
    end

    context 'when the work is contained in a volume' do
      let(:manifestation) { create(:manifestation, title: 'Test Contained Work') }

      it 'names the containing collection and its pub_year after the linked title' do
        expect(results).to include('בתוך: Containing Volume (1923)')
      end
    end

    context 'when the volume has no pub_year' do
      let(:manifestation) { create(:manifestation, title: 'Test Contained Work') }
      let(:volume) do
        create(:collection, collection_type: :volume, title: 'Yearless Volume', pub_year: nil,
                            manifestations: [manifestation])
      end

      it 'names the collection without an empty parenthesis' do
        expect(results).to include('בתוך: Yearless Volume')
        expect(results).not_to include('Yearless Volume (')
      end
    end

    context 'when the work is contained in a series inside a volume' do
      let(:manifestation) { create(:manifestation, title: 'Test Nested Work') }
      let(:series) { create(:collection, collection_type: :series, manifestations: [manifestation]) }
      let(:volume) do
        create(:collection, collection_type: :volume, title: 'Outer Volume', pub_year: '1948',
                            included_collections: [series])
      end

      it 'names the volume the series sits in' do
        expect(results).to include('בתוך: Outer Volume (1948)')
      end
    end

    context 'when the work is in no collection' do
      let(:manifestation) { create(:manifestation, title: 'Test Uncontained Work') }
      let(:volume) { nil }

      it 'does not render a containment label' do
        expect(results).to include('Test Uncontained Work')
        expect(results).not_to include('בתוך:')
      end
    end
  end
end
