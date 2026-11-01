# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search results containment', type: :request do
  describe 'GET /search/results' do
    subject(:results) do
      get search_results_internal_path, params: { q: 'Test', index_types: ['manifestations'] }
      response.body
    end

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

  describe 'GET /search/results for sections' do
    subject(:results) do
      get search_results_internal_path, params: { q: 'Test', index_types: ['collections'] }
      response.body
    end

    let(:section) { create(:collection, collection_type: :series, title: 'Test Section') }

    before do
      clean_tables
      Chewy.strategy(:atomic) do
        section
        volume
      end
    end

    context 'when the section sits in a volume' do
      let(:volume) do
        create(:collection, collection_type: :volume, title: 'Section Volume', pub_year: '1931',
                            included_collections: [section])
      end

      it 'names the volume the section belongs to' do
        expect(results).to include('Test Section')
        expect(results).to include('בתוך: Section Volume (1931)')
      end
    end

    context 'when the section sits in a series inside a periodical issue' do
      let(:outer_series) do
        create(:collection, collection_type: :series, title: 'Outer Grouping', included_collections: [section])
      end
      let(:volume) do
        create(:collection, collection_type: :periodical_issue, title: 'Issue 7', pub_year: nil,
                            included_collections: [outer_series])
      end

      it 'names the nearest volume or issue ancestor' do
        expect(results).to include('בתוך: Issue 7')
      end
    end

    context 'when the section is in no volume or issue' do
      let(:volume) { nil }

      it 'does not render a containment label' do
        expect(results).to include('Test Section')
        expect(results).not_to include('בתוך:')
      end
    end
  end
end
