# frozen_string_literal: true

require 'rails_helper'

describe 'Collection show page - original language of translated works' do
  # A collection containing exactly one manifestation auto-redirects to that
  # manifestation's own page, so we need at least two items to actually
  # exercise the collection#show rendering.
  let!(:translated_manifestation) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Translated Text', orig_lang: 'ru', language: 'he',
                             markdown: 'Translated content', status: :published)
    end
  end

  let!(:original_manifestation) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Original Text', orig_lang: 'he', language: 'he',
                             markdown: 'Original content', status: :published)
    end
  end

  # collection_type must be pinned: the factory otherwise samples it randomly
  # from %w[volume periodical series other], and a 'periodical' collection uses
  # a different issue/volume layout that does NOT render the .by-card-v02
  # manifestation cards this spec asserts on. Leaving it unpinned made the spec
  # flaky in full-suite runs (the sampled value depends on PRNG state polluted
  # by earlier specs). A 'volume' matches the intent: an anthology of works.
  let!(:collection) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Test Collection', collection_type: :volume,
                          manifestations: [translated_manifestation, original_manifestation])
    end
  end

  after do
    Chewy.massacre
  end

  it 'shows the original language next to the translator name for translated works only' do
    visit collection_path(collection)

    translated_card = find(".by-card-v02.proofable[data-item-id='#{translated_manifestation.id}']", wait: 10)
    within(translated_card) do
      expect(page).to have_text(I18n.t(:translated_by))
      expect(page).to have_text("#{I18n.t(:from_lang)}#{I18n.t(:russian)}")
    end

    original_card = find(".by-card-v02.proofable[data-item-id='#{original_manifestation.id}']")
    within(original_card) do
      expect(page).not_to have_text(I18n.t(:translated_by))
    end
  end
end
