# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/citation_authors' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }
  let!(:citation) { create(:lex_citation, person: person) }
  let(:author) { citation.authors.first }

  let(:invalid_attrs) { { name: '' } }

  describe 'GET /lexicon/citations/:citation_id/authors' do
    subject(:call) { get "/lex/citations/#{citation.id}/authors" }

    it { is_expected.to eq(200) }

    context 'with an author added by picking an entry, carrying no name of its own' do
      before do
        entry = create(:lex_entry, :person, title: 'תלמה אדמון (1949)')
        citation.authors.create!(entry: entry, name: nil, link: nil)
      end

      it 'lists the author surname-first, as migrated authors are listed' do
        call
        expect(response.body).to include('אדמון, תלמה')
      end
    end

    context 'with many entry-only authors' do
      # Deriving a display name reaches into the entry (and, for an entry still awaiting
      # ingestion, its lex_file), so the action has to preload both or it pays a query per
      # author. Compare one author against ten: a constant gap means the preloads hold.
      def create_authors(count)
        count.times do
          file = create(:lex_file, :person, entry_status: :raw)
          citation.authors.create!(entry: file.lex_entry, name: nil, link: nil)
        end
      end

      it 'does not issue more queries as authors are added' do
        # not the memoized `call` subject: each request has to actually be issued
        request_authors = -> { get "/lex/citations/#{citation.id}/authors" }

        create_authors(1)
        request_authors.call # warm up: the first request of the example costs one extra query
        baseline = count_queries(&request_authors)

        citation.authors.destroy_all
        create_authors(10)

        expect(count_queries(&request_authors)).to eq(baseline)
      end
    end
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

    context 'when both name and lex_entry_id are provided' do
      let(:author_entry) { create(:lex_entry, :person) }
      let(:attrs) { { name: 'Custom Author', lex_entry_id: author_entry.id } }

      it 'creates a new author referencing LexEntry and sets name to nil' do
        expect { call }.to change { LexCitationAuthor.count }.by(1)
        expect(response).to have_http_status(:ok)

        author = LexCitationAuthor.order(id: :desc).first
        expect(author.name).to be_nil
        expect(author.entry).to eq(author_entry)
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
