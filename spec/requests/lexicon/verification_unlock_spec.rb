# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification unlock', type: :request do
  let(:entry) { create(:lex_entry, :person, status: :verifying) }

  describe 'PATCH /lex/verification/:id/unlock' do
    context 'when the entry is locked by the current user' do
      it 'releases the lock and redirects to the verification queue' do
        editor = login_as_lexicon_editor
        entry.obtain_lock?(editor)

        patch "/lex/verification/#{entry.id}/unlock"

        expect(response).to redirect_to(lexicon_verification_queue_path)
        expect(flash[:notice]).to eq(I18n.t('lexicon.verification.unlock.success'))
        expect(entry.reload).not_to be_locked
        expect(entry.locked_by_user).to be_nil
      end
    end

    context 'when the entry is locked by another user' do
      it 'leaves the lock alone and redirects to the queue with an alert' do
        # NB: not create_lexicon_editor, which memoizes and would hand back the logged-in user
        other_editor = create(:user, editor: true)
        entry.obtain_lock?(other_editor)
        login_as_lexicon_editor

        patch "/lex/verification/#{entry.id}/unlock"

        expect(response).to redirect_to(lexicon_verification_queue_path)
        expect(flash[:alert]).to eq(I18n.t('lexicon.verification.unlock.not_locked_by_you'))
        expect(entry.reload).to be_locked
        expect(entry.locked_by_user).to eq(other_editor)
      end
    end
  end

  describe 'GET /lex/verification/:id' do
    it 'renders the release-lock button' do
      login_as_lexicon_editor
      entry.start_verification!('editor@example.com')

      get "/lex/verification/#{entry.id}"

      expect(response.body).to include(I18n.t('lexicon.verification.show.release_lock'))
      expect(response.body).to include("/lex/verification/#{entry.id}/unlock")
    end
  end
end
