# frozen_string_literal: true

require 'rails_helper'

describe AuthorsController do
  describe '#kwic' do
    context 'with an authority having multiple manifestations' do
      subject do
        create(:involved_authority, authority: authority, item: work1, role: :author)
        create(:involved_authority, authority: authority, item: work2, role: :author)
        get :kwic, params: { id: authority.id }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:expression1) { create(:expression, work: work1) }
      let(:expression2) { create(:expression, work: work2) }
      let(:work1) { create(:work) }
      let(:work2) { create(:work) }
      let(:manifestation1) do
        create(
          :manifestation,
          title: 'First Work',
          markdown: 'The quick brown fox.',
          expression: expression1,
          status: :published
        )
      end
      let(:manifestation2) do
        create(
          :manifestation,
          title: 'Second Work',
          markdown: 'The brown bear.',
          expression: expression2,
          status: :published
        )
      end

      before do
        manifestation1
        manifestation2
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
        create(:involved_authority, authority: authority, item: work, role: :author)
        get :kwic, params: { id: authority.id, per_page: 50, page: 2 }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        long_text = Array.new(100) { Faker::Lorem.paragraph }.join(' ')
        create(:manifestation, markdown: long_text, expression: expression, status: :published)
      end

      before { manifestation }

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
        create(:involved_authority, authority: authority, item: work, role: :author)
        get :kwic, params: { id: authority.id, filter: 'quick' }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'The quick brown fox. The slow turtle.',
          expression: expression,
          status: :published
        )
      end

      before { manifestation }

      it 'filters concordance entries' do
        subject
        expect(assigns(:filter_text)).to eq('quick')
        assigns(:concordance_data).each do |entry|
          expect(entry[:token]).to include('quick')
        end
      end
    end

    context 'with authority having no works' do
      subject { get :kwic, params: { id: empty_authority.id } }

      let(:empty_authority) { create(:authority, status: :published) }

      it 'redirects with error' do
        subject
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to be_present
      end
    end

    context 'with authority having both original works and translations' do
      subject do
        create(:involved_authority, authority: authority, item: work1, role: :author)
        create(:involved_authority, authority: authority, item: expression2, role: :translator)
        get :kwic, params: { id: authority.id }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work1) { create(:work) }
      let(:work2) { create(:work) }
      let(:expression1) { create(:expression, work: work1) }
      let(:expression2) { create(:expression, work: work2, translation: true) }
      let(:manifestation1) do
        create(
          :manifestation,
          title: 'Original Work',
          markdown: 'Original content here.',
          expression: expression1,
          status: :published
        )
      end
      let(:manifestation2) do
        create(
          :manifestation,
          title: 'Translated Work',
          markdown: 'Translated content here.',
          expression: expression2,
          status: :published
        )
      end

      before do
        manifestation1
        manifestation2
      end

      it 'includes manifestations from both original works and translations' do
        subject
        expect(assigns(:concordance_data)).to be_present
        # Should find tokens from both manifestations
        original_entry = assigns(:concordance_data).find { |e| e[:token] == 'Original' }
        translated_entry = assigns(:concordance_data).find { |e| e[:token] == 'Translated' }
        expect(original_entry).to be_present
        expect(translated_entry).to be_present
      end
    end

    context 'with Hebrew texts' do
      subject do
        create(:involved_authority, authority: authority, item: work1, role: :author)
        create(:involved_authority, authority: authority, item: work2, role: :author)
        get :kwic, params: { id: authority.id }
      end

      let(:authority) { create(:authority, name: 'סופר עברי', status: :published) }
      let(:work1) { create(:work) }
      let(:work2) { create(:work) }
      let(:expression1) { create(:expression, work: work1) }
      let(:expression2) { create(:expression, work: work2) }
      let(:manifestation1) do
        create(:manifestation, title: 'יצירה ראשונה', markdown: 'טקסט עברי ראשון.', expression: expression1, status: :published)
      end
      let(:manifestation2) do
        create(:manifestation, title: 'יצירה שנייה', markdown: 'טקסט עברי שני.', expression: expression2, status: :published)
      end

      before do
        manifestation1
        manifestation2
      end

      it 'generates concordance from Hebrew texts' do
        subject
        tokens = assigns(:concordance_data).map { |e| e[:token] }
        expect(tokens).to include('עברי')
      end
    end

    context 'with sort parameter' do
      context 'alphabetical sort' do
        subject do
          create(:involved_authority, authority: authority, item: work, role: :author)
          get :kwic, params: { id: authority.id, sort: 'alphabetical' }
        end

        let(:authority) { create(:authority, status: :published) }
        let(:work) { create(:work) }
        let(:expression) { create(:expression, work: work) }
        let(:manifestation) do
          create(:manifestation, markdown: 'zebra apple banana apple zebra apple cherry', expression: expression, status: :published)
        end

        before { manifestation }

        it 'sorts tokens alphabetically' do
          subject
          tokens = assigns(:concordance_data).map { |e| e[:token] }
          expect(tokens).to eq(tokens.sort)
        end

        it 'assigns sort_by variable' do
          subject
          expect(assigns(:sort_by)).to eq('alphabetical')
        end
      end

      context 'frequency sort' do
        subject do
          create(:involved_authority, authority: authority, item: work, role: :author)
          get :kwic, params: { id: authority.id, sort: 'frequency' }
        end

        let(:authority) { create(:authority, status: :published) }
        let(:work) { create(:work) }
        let(:expression) { create(:expression, work: work) }
        let(:manifestation) do
          create(:manifestation, markdown: 'apple banana apple cherry apple banana apple', expression: expression, status: :published)
        end

        before { manifestation }

        it 'sorts tokens by frequency descending' do
          subject
          frequencies = assigns(:concordance_data).map { |e| e[:instances].length }
          expect(frequencies).to eq(frequencies.sort.reverse)
        end

        it 'assigns sort_by variable' do
          subject
          expect(assigns(:sort_by)).to eq('frequency')
        end

        it 'places most frequent token first' do
          subject
          first_token = assigns(:concordance_data).first[:token]
          expect(first_token).to eq('apple')
          expect(assigns(:concordance_data).first[:instances].length).to eq(4)
        end
      end

      context 'no sort parameter' do
        subject do
          create(:involved_authority, authority: authority, item: work, role: :author)
          get :kwic, params: { id: authority.id }
        end

        let(:authority) { create(:authority, status: :published) }
        let(:work) { create(:work) }
        let(:expression) { create(:expression, work: work) }
        let(:manifestation) { create(:manifestation, markdown: 'zebra apple banana', expression: expression, status: :published) }

        before { manifestation }

        it 'defaults to alphabetical' do
          subject
          expect(assigns(:sort_by)).to eq('alphabetical')
          tokens = assigns(:concordance_data).map { |e| e[:token] }
          expect(tokens).to eq(tokens.sort)
        end
      end
    end

    context 'with filter and sort combined' do
      subject do
        create(:involved_authority, authority: authority, item: work, role: :author)
        get :kwic, params: { id: authority.id, filter: 'ow', sort: 'frequency' }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'brown fox brown bear brown owl yellow brown crown brown',
          expression: expression,
          status: :published
        )
      end

      before { manifestation }

      it 'filters then sorts by frequency' do
        subject
        # Should have tokens containing 'ow'
        filtered_tokens = assigns(:concordance_data).map { |e| e[:token] }
        filtered_tokens.each { |token| expect(token).to include('ow') }
        
        # Should be sorted by frequency
        frequencies = assigns(:concordance_data).map { |e| e[:instances].length }
        expect(frequencies).to eq(frequencies.sort.reverse)
        
        # 'brown' should be first (5 occurrences)
        expect(assigns(:concordance_data).first[:token]).to eq('brown')
      end
    end
  end

  describe '#kwic_download' do
    context 'with authority having multiple manifestations' do
      subject do
        create(:involved_authority, authority: authority, item: work1, role: :author)
        create(:involved_authority, authority: authority, item: work2, role: :author)
        get :kwic_download, params: { id: authority.id }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work1) { create(:work) }
      let(:work2) { create(:work) }
      let(:expression1) { create(:expression, work: work1) }
      let(:expression2) { create(:expression, work: work2) }
      let(:manifestation1) do
        create(:manifestation, title: 'First Work', markdown: 'The quick brown fox.', expression: expression1, status: :published)
      end
      let(:manifestation2) do
        create(:manifestation, title: 'Second Work', markdown: 'The brown bear.', expression: expression2, status: :published)
      end

      before do
        manifestation1
        manifestation2
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
        create(:involved_authority, authority: authority, item: work, role: :author)
        get :kwic_download, params: { id: authority.id, filter: 'brown' }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'The quick brown fox. The brown bear. The red car.',
          expression: expression,
          status: :published
        )
      end

      before { manifestation }

      it 'filters concordance before download' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('brown')
        expect(content).not_to include('מילה: red')
      end
    end

    context 'with Hebrew authority' do
      subject do
        create(:involved_authority, authority: authority, item: work, role: :author)
        get :kwic_download, params: { id: authority.id }
      end

      let(:authority) { create(:authority, name: 'סופר עברי', status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(:manifestation, markdown: 'טקסט עברי עם מילים.', expression: expression, status: :published)
      end

      before { manifestation }

      it 'generates Hebrew concordance' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('מילה: עברי')
      end
    end
  end

  describe '#kwic_context' do
    context 'with valid manifestation and paragraph' do
      subject do
        get :kwic_context, params: { id: authority.id, manifestation_id: manifestation.id, paragraph: 2 }
      end

      let(:authority) { create(:authority, status: :published) }
      let(:work) { create(:work) }
      let(:expression) { create(:expression, work: work) }
      let(:manifestation) do
        create(
          :manifestation,
          markdown: "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.",
          expression: expression,
          status: :published
        )
      end

      before do
        create(:involved_authority, authority: authority, item: work, role: :author)
        manifestation
      end

      it 'returns JSON response' do
        subject
        expect(response.content_type).to include('application/json')
      end

      it 'returns context paragraphs' do
        subject
        json = JSON.parse(response.body)
        expect(json['prev']).to eq('First paragraph.')
        expect(json['current']).to eq('Second paragraph.')
        expect(json['next']).to eq('Third paragraph.')
      end
    end
  end
end
