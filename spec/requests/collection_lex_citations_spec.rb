# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection LexCitations', type: :request do
  let(:collection) { create(:collection, collection_type: :volume) }
  let(:lex_person) { create(:lex_entry, :person).lex_item }

  describe 'GET /collections/:id' do
    context 'when the collection is linked to a LexPersonWork that has citations' do
      let(:lex_person_work) { create(:lex_person_work, person: lex_person, collection: collection) }
      let!(:lex_citation) do
        create(:lex_citation,
               person: lex_person,
               person_work: lex_person_work,
               title: 'Test Citation',
               from_publication: 'Test Publication')
      end

      it 'assigns @lex_citations with the work\'s citations' do
        get collection_path(collection)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to include(lex_citation)
      end

      it 'displays citations in the view' do
        get collection_path(collection)

        expect(response.body).to include(I18n.t(:lex_citations_about_collection))
        expect(response.body).to include('Test Citation')
        expect(response.body).to include('Test Publication')
      end
    end

    context 'when the collection is linked to a LexPersonWork with no citations' do
      before { create(:lex_person_work, person: lex_person, collection: collection) }

      it 'assigns empty @lex_citations' do
        get collection_path(collection)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display citations card' do
        get collection_path(collection)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end

    context 'when the collection is not linked to any LexPersonWork' do
      it 'assigns empty @lex_citations' do
        get collection_path(collection)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display citations card' do
        get collection_path(collection)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end

    context 'when a sibling LexPersonWork of the same publication has citations' do
      let(:publication) { create(:publication, authority: create(:authority)) }
      let(:sibling_work) { create(:lex_person_work, person: lex_person, publication: publication) }
      let!(:sibling_citation) do
        create(:lex_citation, person: lex_person, person_work: sibling_work, title: 'Sibling Citation')
      end

      before do
        collection.update!(publication: publication)
        create(:lex_person_work, person: lex_person, publication: publication, collection: collection)
      end

      it 'does not leak the sibling work\'s citations onto this collection' do
        get collection_path(collection)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).not_to include(sibling_citation)
      end
    end
  end
end
