# frozen_string_literal: true

require 'rails_helper'

describe CollectionsController do
  describe '#kwic' do
    context 'with a collection containing multiple manifestations' do
      subject do
        create(:collection_item, collection: collection, item: manifestation1)
        create(:collection_item, collection: collection, item: manifestation2)
        get :kwic, params: { collection_id: collection.id }
      end

      let(:collection) { create(:collection, title: 'Test Collection') }
      let(:manifestation1) do
        create(
          :manifestation,
          title: 'First Work',
          markdown: 'The quick brown fox.'
        )
      end
      let(:manifestation2) do
        create(
          :manifestation,
          title: 'Second Work',
          markdown: 'The brown bear.'
        )
      end

      it 'returns success' do
        subject
        expect(response).to have_http_status(:success)
      end

      it 'assigns concordance data from all manifestations' do
        subject
        expect(assigns(:concordance_data)).to be_present
        # Should have data from both manifestations
        brown_entry = assigns(:concordance_data).find { |e| e[:token] == 'brown' }
        expect(brown_entry).to be_present
        expect(brown_entry[:instances].length).to eq(2) # One from each text
      end

      it 'assigns pagination variables' do
        subject
        expect(assigns(:per_page)).to eq(25)
        expect(assigns(:page)).to eq(1)
        expect(assigns(:total_entries)).to be > 0
      end

      it 'renders kwic template' do
        subject
        expect(response).to render_template(:kwic)
      end
    end

    context 'with pagination parameters' do
      subject do
        create(:collection_item, collection: collection, item: manifestation)
        get :kwic, params: { collection_id: collection.id, per_page: 50, page: 2 }
      end

      let(:collection) { create(:collection) }
      let(:manifestation) do
        long_text = Array.new(100) { Faker::Lorem.paragraph }.join(' ')
        create(:manifestation, markdown: long_text)
      end

      it 'respects per_page parameter' do
        subject
        expect(assigns(:per_page)).to eq(50)
      end

      it 'respects page parameter' do
        subject
        expect(assigns(:page)).to eq(2)
      end
    end

    context 'with filter parameter' do
      subject do
        create(:collection_item, collection: collection, item: manifestation)
        get :kwic, params: { collection_id: collection.id, filter: 'quick' }
      end

      let(:collection) { create(:collection) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'The quick brown fox. The slow turtle.'
        )
      end

      it 'filters concordance entries' do
        subject
        expect(assigns(:filter_text)).to eq('quick')
        assigns(:concordance_data).each do |entry|
          expect(entry[:token]).to include('quick')
        end
      end
    end

    context 'with empty collection' do
      subject { get :kwic, params: { collection_id: empty_collection.id } }

      let(:empty_collection) { create(:collection) }

      it 'redirects with error' do
        subject
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to be_present
      end
    end

    context 'with nested collections' do
      subject do
        # Create nested structure: collection -> sub_collection -> manifestation
        create(:collection_item, collection: sub_collection, item: manifestation)
        create(:collection_item, collection: collection, item: sub_collection)
        get :kwic, params: { collection_id: collection.id }
      end

      let(:collection) { create(:collection, title: 'Parent Collection') }
      let(:sub_collection) { create(:collection, title: 'Sub Collection') }
      let(:manifestation) do
        create(
          :manifestation,
          title: 'Nested Work',
          markdown: 'Nested content here.'
        )
      end

      it 'includes manifestations from nested collections' do
        subject
        expect(assigns(:concordance_data)).to be_present
        # Should find 'Nested' token from the nested manifestation
        nested_entry = assigns(:concordance_data).find { |e| e[:token] == 'Nested' }
        expect(nested_entry).to be_present
      end
    end

    context 'with Hebrew texts in collection' do
      subject do
        create(:collection_item, collection: collection, item: manifestation1)
        create(:collection_item, collection: collection, item: manifestation2)
        get :kwic, params: { collection_id: collection.id }
      end

      let(:collection) { create(:collection, title: 'אוסף עברי') }
      let(:manifestation1) do
        create(:manifestation, title: 'יצירה ראשונה', markdown: 'טקסט עברי ראשון.')
      end
      let(:manifestation2) do
        create(:manifestation, title: 'יצירה שנייה', markdown: 'טקסט עברי שני.')
      end

      it 'generates concordance from Hebrew texts' do
        subject
        tokens = assigns(:concordance_data).map { |e| e[:token] }
        expect(tokens).to include('עברי')
      end
    end
  end

  describe '#kwic_download' do
    context 'with collection containing multiple manifestations' do
      subject do
        create(:collection_item, collection: collection, item: manifestation1)
        create(:collection_item, collection: collection, item: manifestation2)
        get :kwic_download, params: { collection_id: collection.id }
      end

      let(:collection) { create(:collection, title: 'Test Collection') }
      let(:manifestation1) do
        create(:manifestation, title: 'First Work', markdown: 'The quick brown fox.')
      end
      let(:manifestation2) do
        create(:manifestation, title: 'Second Work', markdown: 'The brown bear.')
      end

      it 'returns success' do
        subject
        expect(response).to have_http_status(:success)
      end

      it 'sets correct content type' do
        subject
        expect(response.content_type).to eq('text/plain; charset=utf-8')
      end

      it 'generates concordance from all manifestations' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('קונקורדנציה בתבנית KWIC')
        expect(content).to include('מילה: brown')
        expect(content).to include('[First Work')
        expect(content).to include('[Second Work')
      end
    end

    context 'with filter parameter' do
      subject do
        create(:collection_item, collection: collection, item: manifestation)
        get :kwic_download, params: { collection_id: collection.id, filter: 'brown' }
      end

      let(:collection) { create(:collection) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'The quick brown fox. The brown bear. The red car.'
        )
      end

      it 'filters concordance before download' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('brown')
        expect(content).not_to include('מילה: red')
      end
    end

    context 'with Hebrew collection' do
      subject do
        create(:collection_item, collection: collection, item: manifestation)
        get :kwic_download, params: { collection_id: collection.id }
      end

      let(:collection) { create(:collection, title: 'אוסף עברי') }
      let(:manifestation) do
        create(:manifestation, markdown: 'טקסט עברי עם מילים.')
      end

      it 'generates Hebrew concordance' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('מילה: עברי')
      end
    end
  end
end
