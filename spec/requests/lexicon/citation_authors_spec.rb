# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/citation_authors' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_person) }
  let!(:citation) { create(:lex_citation, person: person) }
  let(:author) { citation.authors.first }

  let(:invalid_attrs) { { name: '' } }

  describe 'GET /lexicon/citations/:citation_id/authors' do
    subject { get "/lex/citations/#{citation.id}/authors" }

    it { is_expected.to eq(200) }
  end

  describe 'POST /lexicon/citations/:citation_id/authors' do
    subject(:call) { post "/lex/citations/#{citation.id}/authors", params: { lex_citation_author: attrs }, xhr: true }

    context 'with valid params' do
      let(:attrs) { attributes_for(:lex_citation_author) }

      it 'creates a new author for the citation' do
        expect { call }.to change { LexCitationAuthor.count }.by(1)
        expect(response).to have_http_status(:ok)

        author = LexCitationAuthor.order(id: :desc).first
        expect(author).to have_attributes(attrs)
        expect(author.citation).to eq(citation)
      end
    end

    context 'when both name and lex_person_id are provided' do
      let(:author_person) { create(:lex_person) }
      let(:attrs) { { name: 'Custom Author', lex_person_id: author_person.id } }

      it 'creates a new author referencing LexPerson and sets name to nil' do
        expect { call }.to change { LexCitationAuthor.count }.by(1)
        expect(response).to have_http_status(:ok)

        author = LexCitationAuthor.order(id: :desc).first
        expect(author.name).to be_nil
        expect(author.person).to eq(author_person)
        expect(author.citation).to eq(citation)
      end
    end

    context 'with invalid params' do
      let(:attrs) { { name: nil } }

      it 'fails with Unprocessable Cotnent status' do
        expect { call }.not_to(change { LexCitationAuthor.count })
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE /lexicon/citation_authors/:id' do
    subject(:call) { delete "/lex/citation_authors/#{author.id}", xhr: true }

    it 'destroys the requested author' do
      expect { call }.to change { citation.authors.count }.by(-1)
      expect(call).to eq(200)
    end
  end
end
