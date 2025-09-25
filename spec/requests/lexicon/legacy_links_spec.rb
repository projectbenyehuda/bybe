# frozen_string_literal: true

require 'rails_helper'

describe 'Legacy Links' do
  describe 'GET /lexicon/<LEGACYLINK>' do
    subject { get '/lex/files-001/1.jpg' }

    context 'when no Legacy Link for requested path exists' do
      it { is_expected.to eq(404) }
    end

    context 'when Legacy Link for requested path exists' do
      let(:lex_entry) { create(:lex_entry, :person) }
      let!(:lex_legacy_link) { create(:lex_legacy_link, old_path: 'files-001/1.jpg', lex_entry: lex_entry) }

      it { is_expected.to redirect_to(lex_legacy_link.new_path) }
    end
  end
end
