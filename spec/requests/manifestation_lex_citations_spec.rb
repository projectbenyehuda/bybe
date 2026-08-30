# frozen_string_literal: true

require 'rails_helper'

# A one-text volume simply *is* that text, so the lexicon's citations about the book are shown on
# the text's own page as well as on the collection's. See Manifestation#sole_containing_collection.
RSpec.describe 'Manifestation LexCitations', type: :request do
  let(:manifestation) { create(:manifestation) }
  let(:volume) { create(:collection, collection_type: :volume) }
  let(:lex_person) { create(:lex_entry, :person).lex_item }
  let(:lex_person_work) { create(:lex_person_work, person: lex_person, collection: volume) }

  let!(:lex_citation) do
    create(:lex_citation,
           person: lex_person,
           person_work: lex_person_work,
           title: 'Test Citation',
           from_publication: 'Test Publication')
  end

  describe 'GET /read/:id' do
    context 'when the manifestation is the only item of the volume' do
      before { create(:collection_item, collection: volume, item: manifestation) }

      it 'assigns @lex_citations with the volume\'s citations' do
        get manifestation_path(manifestation)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to include(lex_citation)
      end

      it 'displays the citations card' do
        get manifestation_path(manifestation)

        expect(response.body).to include(I18n.t(:lex_citations_about_collection))
        expect(response.body).to include('Test Citation')
        expect(response.body).to include('Test Publication')
      end
    end

    # The volume page redirects to this text (CollectionsController#show redirects when a collection
    # flattens to one manifestation), so if the card did not appear here it would appear nowhere.
    context 'when the volume holds the manifestation through a series' do
      before do
        series = create(:collection, collection_type: :series)
        create(:collection_item, collection: volume, item: series)
        create(:collection_item, collection: series, item: manifestation)
      end

      it 'displays the citations card' do
        get manifestation_path(manifestation)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to include(lex_citation)
        expect(response.body).to include('Test Citation')
      end
    end

    context 'when the volume holds other texts as well' do
      before do
        create(:collection_item, collection: volume, item: manifestation)
        create(:collection_item, collection: volume, item: create(:manifestation))
      end

      it 'assigns empty @lex_citations' do
        get manifestation_path(manifestation)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display the citations card, which belongs to the volume, not to one text' do
        get manifestation_path(manifestation)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end

    context 'when the manifestation is in no collection' do
      it 'assigns empty @lex_citations' do
        get manifestation_path(manifestation)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display the citations card' do
        get manifestation_path(manifestation)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end

    context 'when the sole containing volume has no lexicon work linked to it' do
      let(:bare_volume) { create(:collection, collection_type: :volume) }

      before { create(:collection_item, collection: bare_volume, item: manifestation) }

      it 'assigns empty @lex_citations' do
        get manifestation_path(manifestation)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display the citations card' do
        get manifestation_path(manifestation)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end
  end
end
