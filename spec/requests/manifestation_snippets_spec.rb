# frozen_string_literal: true

require 'rails_helper'

# The batch snippets endpoint feeding the Authority TOC's summaries view
# (bead r81). The JS that calls it is covered by the system spec.
RSpec.describe 'Manifestation snippets', type: :request do
  let!(:poem) { create(:manifestation, title: 'Alpha Poem', markdown: 'The opening line of the Alpha poem.') }
  let!(:story) { create(:manifestation, title: 'Beta Story', markdown: 'The opening line of the Beta story.') }

  it 'returns the rendered card of every requested work, keyed by id' do
    get manifestation_snippets_path, params: { ids: [poem.id, story.id].join(',') }

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body.keys).to contain_exactly(poem.id.to_s, story.id.to_s)
    expect(body[poem.id.to_s]).to include('The opening line of the Alpha poem.')
    expect(body[story.id.to_s]).to include('The opening line of the Beta story.')
  end

  it 'skips over headings, which would otherwise be the whole snippet' do
    chaptered = create(:manifestation, title: 'Chaptered',
                                       markdown: "## Chaptered\n\n### א\n\nThe text under the first chapter.\n")

    get manifestation_snippets_path, params: { ids: chaptered.id.to_s }

    snippet = response.parsed_body[chaptered.id.to_s]
    expect(snippet).to include('The text under the first chapter.')
    expect(snippet).not_to include('<h')
  end

  it 'ignores ids that are not published works' do
    unpublished = create(:manifestation, title: 'Hidden', status: :unpublished, markdown: 'Secret text.')

    get manifestation_snippets_path, params: { ids: [poem.id, unpublished.id, 0, 'junk'].join(',') }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.keys).to eq([poem.id.to_s])
  end

  it 'serves nothing when no usable ids are given' do
    get manifestation_snippets_path, params: { ids: '' }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({})
  end

  it 'caps how many works one request may ask for' do
    # Ids of no existing work, enough of them to fill the cap on their own; the
    # two real works sit past it, so neither may come back.
    base = Manifestation.maximum(:id) + 1
    filler = (base...(base + ManifestationController::SNIPPET_BATCH_LIMIT)).to_a
    get manifestation_snippets_path, params: { ids: (filler + [poem.id, story.id]).join(',') }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({})
  end

  describe 'the card metadata line' do
    subject(:card) do
      get manifestation_snippets_path, params: { ids: work.id.to_s, authority_id: author.id }
      response.parsed_body[work.id.to_s]
    end

    let(:author) { create(:authority) }

    context 'with an original Hebrew work by the authority whose page it is' do
      let(:work) do
        create(:manifestation, author: author, genre: 'poetry', orig_lang: 'he',
                               markdown: "One two three four five\n")
      end

      it 'states the genre and the word count' do
        expect(card).to include(I18n.t('genre_values.poetry'))
        expect(card).to include("#{I18n.t(:word_count)}: 5")
      end

      it 'names no authorities, the page itself being the attribution' do
        expect(card).not_to include(author.name)
      end

      it 'says nothing of the original language, the work not being a translation' do
        expect(card).not_to include(I18n.t(:orig_lang))
      end
    end

    context 'with a translation' do
      let(:translator) { create(:authority) }
      let(:work) do
        create(:manifestation, author: author, translator: translator, orig_lang: 'ru', markdown: 'Some text.')
      end

      it 'states the language it was translated from' do
        expect(card).to include("#{I18n.t(:orig_lang)}: #{I18n.t(:russian)}")
      end

      it 'names the translator, whose role the page does not imply' do
        expect(card).to include(translator.name)
      end
    end

    context 'when the work sits in a volume, below an intervening series' do
      let(:volume) { create(:collection, collection_type: :volume, title: 'The Collected Poems') }
      let(:series) { create(:collection, collection_type: :series, title: 'Part One') }
      let(:work) { create(:manifestation, author: author, collections: [series], markdown: 'Some text.') }

      before do
        volume.collection_items.create!(item: series, seqno: 1)
      end

      it 'names the volume, ignoring the series in between' do
        expect(card).to include('The Collected Poems')
        expect(card).not_to include('Part One')
      end
    end
  end
end
