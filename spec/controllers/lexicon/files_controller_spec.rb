# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::FilesController, type: :controller do
  before { login_as_lexicon_editor }

  describe '#migrate' do
    subject(:call) { post :migrate, params: { id: lex_file.id } }

    let!(:lex_file) { create(:lex_file, :person) }

    before do
      allow(Lexicon::IngestFile).to receive(:perform_async)
    end

    it 'renders the file row partial with 200 OK' do
      call
      expect(response).to have_http_status(:ok)
    end

    it 'returns the updated row HTML for the file' do
      call
      expect(response.body).to include("lex-file-#{lex_file.id}")
      expect(response.body).to include(lex_file.fname.sub('.php', '').sub('/', ''))
      expect(response.body).to include(lex_file.lex_entry.title)
    end
  end
end
