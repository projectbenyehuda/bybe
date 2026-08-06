# frozen_string_literal: true

require 'rails_helper'

# The entry header's action bar offers lexicon editors a shortcut back to the
# migration file list (/lex/files), so they can keep working through the queue
# after inspecting a migrated entry.
describe 'Back-to-migration-list button on the lexicon entry page' do
  let(:entry) { create(:lex_entry, :person, status: :published) }
  let(:label) { I18n.t('lexicon.entries.show.back_to_migration_list') }

  context 'when signed in as a lexicon editor' do
    before do
      login_as_lexicon_editor
      get "/lex/entries/#{entry.id}"
    end

    it 'renders the button linking to the migration file list' do
      expect(response.body).to include(label)
      expect(response.body).to match(%r{<a[^>]+href="/lex/files"[^>]*>\s*#{Regexp.escape(label)}})
    end
  end

  context 'when signed in as an editor without the edit_lexicon bit' do
    before do
      login_as_catalog_editor
      get "/lex/entries/#{entry.id}"
    end

    it 'does not render the button' do
      expect(response.body).not_to include(label)
    end
  end

  context 'when not signed in' do
    before { get "/lex/entries/#{entry.id}" }

    it 'does not render the button' do
      expect(response.body).not_to include(label)
    end
  end
end
