# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe '/lexicon/files' do
  before do
    login_as_lexicon_editor
  end

  describe '#index' do
    subject(:call) { get '/lex/files', params: params }

    let(:params) { {} }

    before do
      create_list(:lex_file, 2, :person, status: :classified)
      create_list(:lex_file, 2, :person, status: :ingested)
      create_list(:lex_file, 2, :publication, status: :classified)
      create_list(:lex_file, 2, :publication, status: :ingested)
    end

    it 'renders successfully' do
      expect(call).to eq(200)
    end

    context 'when filtering by title' do
      let!(:file_with_title) do
        create(
          :lex_file,
          :person,
          status: :classified,
          title: 'Unique Test Title'
        )
      end

      let(:params) { { title: 'Unique' } }

      it 'filters files by title substring' do
        call
        expect(assigns(:lex_files).map(&:id)).to include(file_with_title.id)
        expect(assigns(:lex_files).count).to be >= 1
      end
    end

    context 'when filtering by title with partial match' do
      let!(:file1) do
        create(
          :lex_file,
          :person,
          status: :classified,
          title: 'Abraham Lincoln'
        )
      end

      let!(:file2) do
        create(
          :lex_file,
          :person,
          status: :classified,
          title: 'Abraham Mapu'
        )
      end

      let(:params) { { title: 'Abraham' } }

      it 'returns all files matching the substring' do
        call
        file_ids = assigns(:lex_files).map(&:id)
        expect(file_ids).to include(file1.id, file2.id)
      end
    end

    context 'when filtering by both entrytype and title' do
      let!(:person_file) do
        create(
          :lex_file,
          :person,
          status: :classified,
          title: 'Test Person'
        )
      end

      let!(:publication_file) do
        create(
          :lex_file,
          :publication,
          status: :classified,
          title: 'Test Publication'
        )
      end

      let(:params) { { entrytype: 'person', title: 'Test' } }

      it 'applies both filters' do
        call
        file_ids = assigns(:lex_files).map(&:id)
        expect(file_ids).to include(person_file.id)
        expect(file_ids).not_to include(publication_file.id)
      end
    end
  end

  describe 'POST /migrate' do
    subject(:call) { post "/lex/files/#{file.id}/migrate" }

    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    context 'when person file is provided', vcr: { cassette_name: 'lexicon/ingest_person/00002' } do
      let!(:file) do
        create(
          :lex_file,
          :person,
          entrytype: :person,
          status: :classified,
          title: 'Gabriella Avigur',
          fname: '00002.php',
          full_path: Rails.root.join('spec/data/lexicon/00002.php')
        )
      end

      it 'add ingestion job to queue and sets entry status to `migrating`' do
        expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
        expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
        expect(call).to redirect_to lexicon_files_path
        expect(flash.notice).to eq(I18n.t('lexicon.files.migrate.success'))
        expect(file.lex_entry.reload.status).to eq('migrating')
      end
    end
  end
end
