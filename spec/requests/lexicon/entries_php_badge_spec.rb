# frozen_string_literal: true

require 'rails_helper'

describe 'PHP badge on public lexicon list (/lex)' do
  subject(:call) { get '/lex' }

  let!(:published_entry) { create(:lex_entry, :person, status: :published, title: 'Published Person') }
  let!(:not_migrated_entry) { create(:lex_entry, :person, status: :verifying, title: 'Verifying Person') }

  context 'when the visitor is an editor' do
    before { login_as_lexicon_editor }

    it 'shows the PHP badge only next to non-published entries' do
      expect(call).to eq(200)
      # One badge total, for the single non-published (not-yet-migrated) entry
      doc = Nokogiri::HTML(response.body)
      expect(doc.css('.lex-php-badge').size).to eq(1)
      expect(doc.css('.lex-php-badge').text).to include(I18n.t('lexicon.entries.list.not_migrated_badge'))
    end
  end

  context 'when the visitor is not an editor (general public)' do
    it 'never shows the PHP badge' do
      expect(call).to eq(200)
      expect(response.body).not_to include('lex-php-badge')
    end
  end
end
