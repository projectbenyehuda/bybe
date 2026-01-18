# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collection LexCitations', type: :request do
  let(:authority) { create(:authority) }
  let(:publication) { create(:publication, authority: authority) }
  let(:collection) { create(:collection, publication: publication) }
  let(:lex_person) { create(:lex_person) }
  let(:lex_person_work) { create(:lex_person_work, person: lex_person, publication: publication) }
  let!(:lex_citation) do
    create(:lex_citation,
           person: lex_person,
           item: lex_person_work,
           title: 'Test Citation',
           from_publication: 'Test Publication',
           status: :manual)
  end

  describe 'GET /collections/:id' do
    context 'when collection has associated citations via publication' do
      it 'assigns @lex_citations with the related citations' do
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

    context 'when collection has no publication' do
      let(:collection_without_pub) { create(:collection, publication: nil) }

      it 'assigns empty @lex_citations' do
        get collection_path(collection_without_pub)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display citations card' do
        get collection_path(collection_without_pub)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end

    context 'when publication has no associated lex_person_works' do
      let(:pub_without_works) { create(:publication, authority: authority) }
      let(:collection_without_works) { create(:collection, publication: pub_without_works) }

      it 'assigns empty @lex_citations' do
        get collection_path(collection_without_works)

        expect(response).to be_successful
        expect(assigns(:lex_citations)).to be_empty
      end

      it 'does not display citations card' do
        get collection_path(collection_without_works)

        expect(response.body).not_to include(I18n.t(:lex_citations_about_collection))
      end
    end
  end
end
