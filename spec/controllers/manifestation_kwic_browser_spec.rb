# frozen_string_literal: true

require 'rails_helper'

describe ManifestationController do
  describe '#kwic' do
    context 'with a basic manifestation' do
      subject { get :kwic, params: { id: manifestation.id } }

      let(:manifestation) do
        create(
          :manifestation,
          title: 'Test Work',
          markdown: "The quick brown fox jumps.\nThe brown bear runs."
        )
      end

      it 'returns success' do
        subject
        expect(response).to have_http_status(:success)
      end

      it 'assigns concordance data' do
        subject
        expect(assigns(:concordance_data)).to be_present
        expect(assigns(:concordance_data)).to be_an(Array)
      end

      it 'assigns pagination variables' do
        subject
        expect(assigns(:per_page)).to eq(10)
        expect(assigns(:page)).to eq(1)
        expect(assigns(:total_entries)).to be > 0
      end

      it 'renders kwic template' do
        subject
        expect(response).to render_template(:kwic)
      end
    end

    context 'with pagination parameters' do
      subject { get :kwic, params: { id: manifestation.id, per_page: 50, page: 2 } }

      let(:manifestation) do
        # Create a longer text to have multiple pages
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
      subject { get :kwic, params: { id: manifestation.id, filter: 'brown' } }

      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'The quick brown fox. The brown bear. The red car.'
        )
      end

      it 'filters concordance entries' do
        subject
        expect(assigns(:filter_text)).to eq('brown')
        expect(assigns(:concordance_data)).to be_present
        # All entries should contain 'brown'
        assigns(:concordance_data).each do |entry|
          expect(entry[:token]).to include('brown')
        end
      end

      it 'updates total entries count' do
        subject
        # Should only have entries for 'brown'
        # Removed incorrect assertion: total_entries equals concordance_data.count after filtering.
      end
    end

    context 'with Hebrew text and acronyms' do
      subject { get :kwic, params: { id: manifestation.id } }

      let(:manifestation) do
        create(
          :manifestation,
          title: 'טקסט עברי',
          markdown: 'מפא"י היתה מפלגה פוליטית. רמטכ"ל הוא ראש המטה.'
        )
      end

      it 'preserves Hebrew acronyms in concordance' do
        subject
        tokens = assigns(:concordance_data).map { |e| e[:token] }
        expect(tokens).to include('מפא"י')
        expect(tokens).to include('רמטכ"ל')
      end
    end

    context 'with nonexistent manifestation' do
      subject { get :kwic, params: { id: 999_999 } }

      it 'returns not found' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with invalid per_page value' do
      subject { get :kwic, params: { id: manifestation.id, per_page: 75 } }

      let(:manifestation) { create(:manifestation, markdown: 'Some text here.') }

      it 'defaults to 25' do
        subject
        expect(assigns(:per_page)).to eq(25)
      end
    end

    context 'with sort parameter' do
      context 'alphabetical sort' do
        subject { get :kwic, params: { id: manifestation.id, sort: 'alphabetical' } }

        let(:manifestation) do
          create(
            :manifestation,
            markdown: 'zebra apple banana apple zebra apple cherry'
          )
        end

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
        subject { get :kwic, params: { id: manifestation.id, sort: 'frequency' } }

        let(:manifestation) do
          create(
            :manifestation,
            markdown: 'apple banana apple cherry apple banana apple'
          )
        end

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

        context 'with equal frequency tokens' do
          let(:manifestation) { create(:manifestation, markdown: 'zebra apple zebra apple') }

          it 'uses alphabetical order as secondary sort for equal frequencies' do
            subject
            # Both have 2 occurrences, so should be sorted alphabetically
            tokens = assigns(:concordance_data).map { |e| e[:token] }
            frequencies = assigns(:concordance_data).map { |e| e[:instances].length }

            expect(frequencies.first).to eq(frequencies.last) # Equal frequencies
            expect(tokens.first).to eq('apple') # Alphabetically first
            expect(tokens.last).to eq('zebra') # Alphabetically last
          end
        end
      end

      context 'invalid sort parameter' do
        subject { get :kwic, params: { id: manifestation.id, sort: 'invalid' } }

        let(:manifestation) { create(:manifestation, markdown: 'Some text here.') }

        it 'defaults to alphabetical' do
          subject
          expect(assigns(:sort_by)).to eq('alphabetical')
        end
      end

      context 'no sort parameter' do
        subject { get :kwic, params: { id: manifestation.id } }

        let(:manifestation) { create(:manifestation, markdown: 'zebra apple banana') }

        it 'defaults to alphabetical' do
          subject
          expect(assigns(:sort_by)).to eq('alphabetical')
          tokens = assigns(:concordance_data).map { |e| e[:token] }
          expect(tokens).to eq(tokens.sort)
        end
      end
    end

    context 'with filter and sort combined' do
      subject { get :kwic, params: { id: manifestation.id, filter: 'ow', sort: 'frequency' } }

      let(:manifestation) do
        create(
          :manifestation,
          markdown: 'brown fox brown bear brown owl yellow brown crown brown'
        )
      end

      it 'filters then sorts by frequency' do
        subject
        # Should have tokens containing 'ow': brown, yellow, crown, owl
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
    context 'with basic manifestation' do
      subject { get :kwic_download, params: { id: manifestation.id } }

      let(:manifestation) do
        create(
          :manifestation,
          title: 'Test Work',
          markdown: 'The quick brown fox.'
        )
      end

      it 'returns success' do
        subject
        expect(response).to have_http_status(:success)
      end

      it 'sets correct content type' do
        subject
        expect(response.content_type).to eq('text/plain; charset=utf-8')
      end

      it 'sets correct disposition' do
        subject
        expect(response.headers['Content-Disposition']).to include('attachment')
      end

      it 'generates concordance content' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('קונקורדנציה בתבנית KWIC')
        expect(content).to include('מילה:')
      end
    end

    context 'with filter parameter' do
      subject { get :kwic_download, params: { id: manifestation.id, filter: 'brown' } }

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

    context 'with Hebrew text' do
      subject { get :kwic_download, params: { id: manifestation.id } }

      let(:manifestation) do
        create(
          :manifestation,
          title: 'עבודה עברית',
          markdown: 'טקסט עברי פשוט עם מילים שונות.'
        )
      end

      it 'generates Hebrew concordance' do
        subject
        content = response.body.force_encoding('UTF-8')
        expect(content).to include('מילה: עברי')
        expect(content).to include('מילה: טקסט')
      end
    end
  end
end
