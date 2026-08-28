# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/entries/<ENTRY_ID>/external_identifiers', type: :request do
  let(:lex_entry) do
    create(:lex_entry, :person, status: :draft, external_identifiers: { 'viaf' => '12345678', 'lc' => 'n87654321' })
  end

  describe 'GET /lexicon/entries/<ENTRY_ID>/external_identifiers' do
    subject(:call) { get "/lex/entries/#{lex_entry.id}/external_identifiers" }

    before do
      login_as_lexicon_editor
    end

    it 'renders a field per identifier key, pre-filled with the stored values' do
      expect(call).to eq(200)

      doc = Nokogiri::HTML(response.body)
      LexiconHelper::EXTERNAL_IDENTIFIER_LABELS.each_key do |key|
        expect(doc.css("input[name='external_identifiers[#{key}]']").count).to eq(1)
      end
      expect(doc.at_css("input[name='external_identifiers[viaf]']")['value']).to eq('12345678')
      expect(doc.at_css("input[name='external_identifiers[lc]']")['value']).to eq('n87654321')
    end

    context 'when loaded as an AJAX fragment' do
      subject(:call) { get "/lex/entries/#{lex_entry.id}/external_identifiers", xhr: true }

      it 'renders without a layout' do
        expect(call).to eq(200)
        expect(response.body).not_to include('<html')
      end
    end

    it 'renders with the layout on direct navigation, so the remote form has its JS assets' do
      expect(call).to eq(200)
      expect(response.body).to include('<html')
    end
  end

  describe 'PATCH /lexicon/entries/<ENTRY_ID>/external_identifiers' do
    subject(:call) do
      patch "/lex/entries/#{lex_entry.id}/external_identifiers",
            params: { external_identifiers: submitted },
            xhr: true
    end

    before do
      login_as_lexicon_editor
    end

    let(:submitted) { { viaf: '99999999', lc: 'n87654321', nli: '', wikidata: 'Q42', openlibrary: '' } }

    it 'stores the submitted identifiers' do
      expect(call).to eq(200)

      expect(lex_entry.reload.external_identifiers).to eq(
        'viaf' => '99999999', 'lc' => 'n87654321', 'wikidata' => 'Q42'
      )
    end

    it 'reports success to the client' do
      call
      expect(response.body).to include(I18n.t('lexicon.external_identifiers.update.success'))
    end

    context 'when a value is cleared' do
      let(:submitted) { { viaf: '12345678', lc: '' } }

      it 'removes that identifier' do
        call
        expect(lex_entry.reload.external_identifiers).to eq('viaf' => '12345678')
      end
    end

    context 'when all values are cleared' do
      let(:submitted) { { viaf: '', lc: '' } }

      it 'nullifies the column rather than storing an empty hash' do
        call
        expect(lex_entry.reload.external_identifiers).to be_nil
      end
    end

    context 'with an unknown identifier key' do
      let(:submitted) { { viaf: '12345678', evil: 'hack' } }

      it 'ignores it' do
        call
        expect(lex_entry.reload.external_identifiers).to eq('viaf' => '12345678')
      end
    end
  end

  describe 'access control' do
    it 'does not let a logged-out visitor read the identifiers' do
      get "/lex/entries/#{lex_entry.id}/external_identifiers"
      expect(response).to redirect_to('/')
    end

    it 'does not let a logged-out visitor change the identifiers' do
      expect do
        patch "/lex/entries/#{lex_entry.id}/external_identifiers",
              params: { external_identifiers: { viaf: 'hacked' } }
      end.not_to(change { lex_entry.reload.external_identifiers })
    end
  end
end
