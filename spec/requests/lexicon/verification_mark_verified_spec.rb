# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /lex/verification/:id/mark_verified', type: :request do
  let(:person) { create(:lex_person) }
  let(:entry) do
    e = create(:lex_entry, :person, lex_item: person, status: :verifying)
    e.start_verification!('editor@example.com')
    e
  end
  let(:url) { "/lex/verification/#{entry.id}/mark_verified" }
  let!(:editor) { login_as_lexicon_editor }

  before do
    # Bypass the full checklist flow; this spec is about what happens *after*
    # verification is deemed complete.
    allow_any_instance_of(LexEntry).to receive(:verification_complete?).and_return(true) # rubocop:disable RSpec/AnyInstance
  end

  context 'when the Monday post succeeds' do
    before { allow(Lexicon::MondayMigrationReport).to receive(:call).and_return({ success: true }) }

    it 'marks the entry as verified' do
      post url

      expect(entry.reload).to be_status_published
      expect(entry.verification_progress['ready_for_publish']).to be true
    end

    it 'reports the entry, verifier and verification URL to the migrated-entries board' do
      post url

      expect(Lexicon::MondayMigrationReport).to have_received(:call).with(
        entry: entry, verifier: editor, entry_url: %r{/lex/verification/#{entry.id}\z}
      )
    end

    it 'releases the lock instead of leaving it to expire' do
      post url

      entry.reload
      expect(entry.locked_at).to be_nil
      expect(entry.locked_by_user).to be_nil
      expect(entry).not_to be_locked
    end

    it 'redirects to the public entry page with a success notice' do
      post url

      expect(response).to redirect_to(lexicon_entry_path(entry))
      expect(flash[:notice]).to eq(I18n.t('lexicon.verification.messages.entry_verified_public'))
      expect(flash[:alert]).to be_blank
    end
  end

  context 'when the Monday post fails' do
    before do
      allow(Lexicon::MondayMigrationReport).to receive(:call).and_return({ success: false, error: 'API error' })
    end

    it 'still marks the entry as verified' do
      post url

      expect(entry.reload).to be_status_published
    end

    it 'still redirects to the public entry page' do
      post url

      expect(response).to redirect_to(lexicon_entry_path(entry))
    end

    it 'warns about the failed report without hiding the success notice' do
      post url

      expect(flash[:alert]).to eq(
        I18n.t('lexicon.verification.monday.migration_report_failed', error: 'API error')
      )
      expect(flash[:notice]).to eq(I18n.t('lexicon.verification.messages.entry_verified_public'))
    end
  end

  context 'when verification is not complete' do
    before do
      allow_any_instance_of(LexEntry).to receive(:verification_complete?).and_return(false) # rubocop:disable RSpec/AnyInstance
      allow(Lexicon::MondayMigrationReport).to receive(:call)
    end

    it 'does not post to Monday' do
      post url

      expect(Lexicon::MondayMigrationReport).not_to have_received(:call)
      expect(entry.reload).not_to be_status_published
    end

    it 'keeps the lock so the editor can carry on verifying' do
      post url

      entry.reload
      expect(entry.locked_by_user).to eq(editor)
      expect(entry).to be_locked
    end
  end
end
