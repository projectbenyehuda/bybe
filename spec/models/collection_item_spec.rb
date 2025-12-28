# frozen_string_literal: true

require 'rails_helper'

describe CollectionItem do
  describe 'Validations' do
    subject(:result) { collection_item.valid? }

    let(:collection_item) { build(:collection_item, collection: collection, item: item) }
    let(:collection) { create(:collection) }

    describe '#ensure_no_cycles' do
      context 'when item is an Manifestation' do
        let(:item) { create(:manifestation) }

        it { is_expected.to be_truthy }
      end

      shared_examples 'fails if cycle is found' do
        it 'fails due to cycle' do
          expect(result).to be false
          expect(collection_item.errors[:collection]).to eq [
            I18n.t('activerecord.errors.models.collection_item.attributes.collection.cycle_found')
          ]
        end
      end

      context 'when item is a collection' do
        context 'when item is the same collection' do
          let(:item) { collection }

          it_behaves_like 'fails if cycle is found'
        end

        context 'when item is another collection' do
          let(:item) { create(:collection) }

          before do
            create(:collection_item, collection: item, item: create(:collection))
          end

          context 'when there is no cycle' do
            it { is_expected.to be_truthy }
          end

          context 'when there is a cycle' do
            before do
              create(:collection_item, collection: item, item: collection)
            end

            it_behaves_like 'fails if cycle is found'
          end
        end
      end
    end
  end

  describe '#to_html' do
    context 'when item is present' do
      let(:collection_item) { build(:collection_item, item: manifestation) }
      let(:manifestation) { create(:manifestation) }

      it 'delegates to item.to_html' do
        expect(manifestation).to receive(:to_html).and_return('<p>Item HTML</p>')
        expect(collection_item.to_html).to eq('<p>Item HTML</p>')
      end
    end

    context 'when item is nil (paratext)' do
      let(:collection_item) { build(:collection_item, item: nil, markdown: markdown) }

      context 'when markdown is blank' do
        let(:markdown) { '' }

        it 'returns empty string' do
          expect(collection_item.to_html).to eq('')
        end
      end

      context 'when markdown contains external links' do
        let(:markdown) { 'Check [this link](https://example.com) and [another](http://test.org)' }

        it 'adds target="_blank" to external links' do
          html = collection_item.to_html
          expect(html).to include('target="_blank"')
          expect(html).to include('href="https://example.com"')
          expect(html).to include('href="http://test.org"')
        end
      end

      context 'when markdown contains internal anchor links' do
        let(:markdown) { 'See [section](#anchor) for details' }

        it 'does not add target="_blank" to internal anchor links' do
          html = collection_item.to_html
          expect(html).to include('href="#anchor"')
          expect(html).not_to include('target="_blank"')
        end
      end

      context 'when markdown contains mixed links' do
        let(:markdown) { '[External](https://example.com) and [internal](#anchor)' }

        it 'adds target="_blank" only to external links' do
          html = collection_item.to_html
          # External link should have target="_blank"
          expect(html).to match(%r{<a [^>]*href="https://example.com"[^>]*target="_blank"[^>]*>})
          # Internal link should not
          expect(html).to match(%r{<a [^>]*href="#anchor"[^>]*>(?!.*target="_blank")})
        end
      end
    end
  end
end
