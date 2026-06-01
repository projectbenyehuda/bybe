# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification bio_comparison', type: :request do
  before do
    login_as_lexicon_editor
  end

  describe 'GET /lex/verification/:id/bio_comparison' do
    context 'when the entry is a LexPerson' do
      let(:entry) do
        create(:lex_entry, :person, status: :verifying,
                                    lex_item: build(:lex_person, bio: 'שלום עולם גדול וטוב'))
      end

      it 'renders the comparison modal with both panes' do
        get "/lex/verification/#{entry.id}/bio_comparison"

        expect(response).to have_http_status(:success)
        expect(response.body).to include(I18n.t('lexicon.verification.bio_comparison.title'))
        expect(response.body).to include(I18n.t('lexicon.verification.bio_comparison.legacy_header'))
        expect(response.body).to include(I18n.t('lexicon.verification.bio_comparison.migrated_header'))
        # Migrated words appear in the diff (legacy source is absent, so they are deletions).
        expect(response.body).to include('שלום')
      end
    end

    context 'when the entry is a LexPublication' do
      let(:entry) { create(:lex_entry, :publication, status: :verifying) }

      it 'returns not found (no biography to compare)' do
        get "/lex/verification/#{entry.id}/bio_comparison"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
