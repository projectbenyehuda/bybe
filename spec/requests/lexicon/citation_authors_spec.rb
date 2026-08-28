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

  describe 'GET /lexicon/citation_authors/:id/match' do
    subject(:call) { get "/lex/citation_authors/#{author.id}/match" }

    let!(:citation) { create(:lex_citation, person: person, authors_count: 0) }
    let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }

    it 'renders the match modal pre-filled with the normalized name' do
      expect(call).to eq(200)
      expect(response.body).to include('גילי איזיקוביץ')
    end
  end

  describe 'PATCH /lexicon/citation_authors/:id' do
    subject(:call) do
      patch "/lex/citation_authors/#{author.id}",
            params: { lex_citation_author: { name: 'גילי איזיקוביץ', lex_entry_id: entry_id } },
            xhr: true
    end

    let!(:citation) { create(:lex_citation, person: person, authors_count: 0) }
    let(:matched_entry) { create(:lex_entry, :person, title: 'גילי איזיקוביץ') }
    let(:entry_id) { matched_entry.id }

    context 'with a plaintext author' do
      let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }

      it 'links the entry without rewriting the imported name' do
        expect(call).to eq(200)
        expect(author.reload.entry).to eq(matched_entry)
        expect(author.name).to eq('איזיקוביץ, גילי')
        expect(author.display_name).to eq('איזיקוביץ, גילי')
      end
    end

    context 'when the author still carries a legacy link' do
      let!(:author) do
        create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: 'http://example.com/gili')
      end

      it 'drops the link, which may not coexist with an entry' do
        expect(call).to eq(200)
        expect(author.reload.entry).to eq(matched_entry)
        expect(author.link).to be_nil
        expect(author.name).to eq('איזיקוביץ, גילי')
      end
    end

    context 'when no entry was selected in the autocomplete' do
      let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }
      let(:entry_id) { '' }

      it 're-renders the modal and leaves the author untouched' do
        expect(call).to eq(422)
        expect(author.reload.entry).to be_nil
        expect(author.name).to eq('איזיקוביץ, גילי')
      end
    end

    context 'when the selected entry is not a person' do
      let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }
      let(:matched_entry) { create(:lex_entry, :publication, title: 'גילי איזיקוביץ') }

      it 're-renders the modal and leaves the author untouched' do
        expect(call).to eq(422)
        expect(author.reload.entry).to be_nil
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
