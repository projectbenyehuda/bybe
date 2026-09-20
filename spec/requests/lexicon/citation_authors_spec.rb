# frozen_string_literal: true

require 'rails_helper'

describe '/lex/citation_authors' do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }
  let!(:citation) { create(:lex_citation, person: person) }
  let(:author) { citation.authors.first }

  let(:invalid_attrs) { { name: '' } }

  def hidden_lex_entry_id_value(body)
    Nokogiri::HTML(body).at_css('#lex_citation_author_lex_entry_id')['value']
  end

  describe 'GET /lex/citations/:citation_id/authors' do
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

  describe 'POST /lex/citations/:citation_id/authors' do
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

  describe 'GET /lex/citation_authors/:id/match' do
    subject(:call) { get "/lex/citation_authors/#{author.id}/match" }

    let!(:citation) { create(:lex_citation, person: person, authors_count: 0) }
    let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }

    it 'renders the match modal pre-filled with the normalized name' do
      expect(call).to eq(200)
      expect(response.body).to include('גילי איזיקוביץ')
    end

    context 'when a person entry is titled exactly like the normalized name' do
      let!(:matching_entry) { create(:lex_entry, :person, title: 'גילי איזיקוביץ') }

      it 'pre-fills the hidden entry id, so confirming without touching the dropdown still submits it' do
        expect(call).to eq(200)
        expect(hidden_lex_entry_id_value(response.body)).to eq(matching_entry.id.to_s)
      end
    end

    context 'when no entry matches the normalized name' do
      it 'leaves the hidden entry id blank' do
        expect(call).to eq(200)
        expect(hidden_lex_entry_id_value(response.body)).to be_blank
      end
    end
  end

  describe 'PATCH /lex/citation_authors/:id' do
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

    # The autocomplete index is only pruned when a destroy runs through the model, so it can still
    # offer an entry whose row is gone. Picking one must not reach the lex_entries foreign key.
    context 'when the selected entry no longer exists' do
      let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }
      let(:entry_id) { matched_entry.id.tap { matched_entry.destroy! } }

      it 're-renders the modal instead of failing on the foreign key' do
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

      it 'keeps the submitted id in the hidden field instead of blanking it' do
        call
        expect(hidden_lex_entry_id_value(response.body)).to eq(matched_entry.id.to_s)
      end
    end
  end

  describe 'GET /lex/citation_authors/:id/edit_link' do
    subject(:call) { get "/lex/citation_authors/#{author.id}/edit_link" }

    let!(:citation) { create(:lex_citation, person: person, authors_count: 0) }
    let!(:author) do
      create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: 'http://example.com/gili')
    end

    it 'renders the modal pre-filled with the current link' do
      expect(call).to eq(200)
      expect(response.body).to include('איזיקוביץ, גילי')
      expect(Nokogiri::HTML(response.body).at_css('#lex_citation_author_link')['value'])
        .to eq('http://example.com/gili')
    end
  end

  describe 'PATCH /lex/citation_authors/:id/update_link' do
    subject(:call) do
      patch "/lex/citation_authors/#{author.id}/update_link",
            params: { lex_citation_author: { link: link } },
            xhr: true
    end

    let!(:citation) { create(:lex_citation, person: person, authors_count: 0) }
    let!(:author) { create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: nil) }
    let(:link) { 'http://example.com/gili' }

    it 'points the plaintext author at the given URL, leaving its name alone' do
      expect(call).to eq(200)
      expect(author.reload.link).to eq('http://example.com/gili')
      expect(author.name).to eq('איזיקוביץ, גילי')
    end

    context 'with surrounding whitespace' do
      let(:link) { '  http://example.com/gili  ' }

      it 'stores the trimmed URL' do
        expect(call).to eq(200)
        expect(author.reload.link).to eq('http://example.com/gili')
      end
    end

    context 'when the field is submitted empty' do
      let!(:author) do
        create(:lex_citation_author, citation: citation, name: 'איזיקוביץ, גילי', link: 'http://example.com/gili')
      end
      let(:link) { '' }

      it 'clears the link rather than storing an empty string' do
        expect(call).to eq(200)
        expect(author.reload.link).to be_nil
      end
    end

    # The value is rendered straight into an href, so the same allowlist TextLinksConcern
    # applies to a text link's url is applied here.
    context 'with a URL of a scheme that could execute script' do
      let(:link) { 'javascript:alert(1)' }

      it 'refuses it and leaves the author untouched' do
        expect(call).to eq(422)
        expect(author.reload.link).to be_nil
      end
    end

    context 'when the author is already linked to a lexicon entry' do
      let!(:author) do
        create(:lex_citation_author, citation: citation, name: nil, link: nil, entry: create(:lex_entry, :person))
      end

      it 'refuses the link, which may not coexist with an entry' do
        expect(call).to eq(422)
        expect(author.reload.link).to be_nil
      end
    end

    context 'when the caller asks for a plain-text response' do
      let(:link) { 'javascript:alert(1)' }
      let(:invalid_url_message) do
        I18n.t('activerecord.errors.models.lex_citation_author.attributes.link.invalid_url')
      end

      it 'reports the reason as text rather than a modal to re-render' do
        patch "/lex/citation_authors/#{author.id}/update_link",
              params: { lex_citation_author: { link: link } },
              headers: { 'Accept' => 'text/plain, */*' },
              xhr: true

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.media_type).to eq('text/plain')
        expect(response.body).to include(invalid_url_message)
      end
    end
  end

  describe 'DELETE /lex/citation_authors/:id' do
    subject(:call) { delete "/lex/citation_authors/#{author.id}", xhr: true }

    it 'destroys the requested author' do
      expect { call }.to change { citation.authors.count }.by(-1)
      expect(call).to eq(200)
    end
  end
end
