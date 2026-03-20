# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::FilesController, type: :controller do
  before { login_as_lexicon_editor }

  describe '#migrate' do
    let!(:lex_file) { create(:lex_file, :person) }

    before do
      allow(Lexicon::IngestFile).to receive(:perform_async)
    end

    context 'without filter params' do
      subject(:call) { post :migrate, params: { id: lex_file.id } }

      it 'redirects to lexicon_files_path with no extra params' do
        call
        expect(response).to redirect_to(lexicon_files_path)
      end
    end

    context 'with filter params' do
      subject(:call) do
        post :migrate, params: { id: lex_file.id, entrytype: 'person', title: 'Test', fname: '001', page: '2' }
      end

      it 'redirects to lexicon_files_path preserving filter and page params' do
        call
        expect(response).to redirect_to(lexicon_files_path(entrytype: 'person', title: 'Test', fname: '001', page: '2'))
      end
    end

    context 'with blank filter params' do
      subject(:call) do
        post :migrate, params: { id: lex_file.id, entrytype: '', title: '', fname: '', page: '' }
      end

      it 'redirects to lexicon_files_path without blank params' do
        call
        expect(response).to redirect_to(lexicon_files_path)
      end
    end
  end
end
