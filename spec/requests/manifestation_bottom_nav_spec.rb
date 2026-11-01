# frozen_string_literal: true

require 'rails_helper'

# Long texts repeat the previous/next navigation buttons below the text.
describe 'Manifestation#read bottom navigation', type: :request do
  let(:volume) { create(:collection, collection_type: :volume) }
  let(:long_markdown) { (['line of text'] * (Manifestation::LONG_TEXT_LINES + 1)).join("\n\n") }
  let(:short_markdown) { "short\n\ntext" }
  let!(:previous_text) { Chewy.strategy(:atomic) { create(:manifestation, orig_lang: 'he', status: :published) } }
  let!(:next_text) { Chewy.strategy(:atomic) { create(:manifestation, orig_lang: 'he', status: :published) } }
  let!(:text) do
    Chewy.strategy(:atomic) do
      create(:manifestation, orig_lang: 'he', status: :published, markdown: markdown)
    end
  end

  before do
    create(:collection_item, collection: volume, item: previous_text, seqno: 1)
    create(:collection_item, collection: volume, item: text, seqno: 2)
    create(:collection_item, collection: volume, item: next_text, seqno: 3)
  end

  after { Chewy.massacre }

  context 'when the text is long' do
    let(:markdown) { long_markdown }

    it 'renders the navigation both above and below the text' do
      get manifestation_path(text)

      doc = Nokogiri::HTML(response.body)
      expect(doc.css('.author-works-nav').size).to eq(2)
      expect(doc.css('.bottom-sibling-nav .author-works-nav a').pluck('href'))
        .to include(manifestation_path(previous_text), manifestation_path(next_text))
      # must stay outside the proofable text so its labels can't end up in a correction report
      expect(doc.css('.proofable .bottom-sibling-nav, .proofable .author-works-nav')).to be_empty
    end
  end

  context 'when the text is short' do
    let(:markdown) { short_markdown }

    it 'renders the navigation only once' do
      get manifestation_path(text)

      doc = Nokogiri::HTML(response.body)
      expect(doc.css('.author-works-nav').size).to eq(1)
      expect(doc.css('.bottom-sibling-nav')).to be_empty
    end
  end
end
