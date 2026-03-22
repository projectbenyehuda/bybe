# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe '/lexicon/files' do
  before do
    login_as_lexicon_editor
  end

  describe '#index' do
    subject(:call) { get '/lex/files', params: params }

    let(:file_ids) { assigns(:lex_files).map(&:id) }

    context 'when no filters are applied' do
      let(:params) { {} }

      before do
        create_list(:lex_file, 2, :person, status: :classified)
        create_list(:lex_file, 2, :person, status: :ingested)
        create_list(:lex_file, 2, :publication, status: :classified)
        create_list(:lex_file, 2, :publication, status: :ingested)
      end

      it 'renders successfully' do
        call
        expect(call).to eq(200)
        expect(file_ids.size).to eq(8)
      end
    end

    context 'when filtering applied' do
      context 'when filtering by title' do
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
          expect(file_ids).to include(file1.id, file2.id)
        end
      end

      context 'when filtering by fname' do
        let!(:person_file) do
          create(
            :lex_file,
            :person,
            status: :classified,
            title: 'Test Person',
            fname: '00003.php'
          )
        end

        let!(:publication_file) do
          create(
            :lex_file,
            :publication,
            status: :classified,
            title: 'Test Publication',
            fname: '000030001.php'
          )
        end

        let(:params) { { fname: '00003' } }

        it 'filters files by title substring' do
          call
          expect(file_ids).to contain_exactly(person_file.id, publication_file.id)
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
          expect(file_ids).to contain_exactly(person_file.id)
        end
      end
    end
  end

  describe 'POST /migrate' do
    subject(:call) { post "/lex/files/#{file.id}/migrate", xhr: true }

    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    context 'when person file is provided', vcr: { cassette_name: 'lexicon/ingest_person/00002' } do
      let!(:file) do
        create(
          :lex_file,
          :person,
          status: :classified,
          title: 'Gabriella Avigur',
          fname: '00002.php',
          entry_status: entry_status,
          full_path: Rails.root.join('spec/data/lexicon/00002.php')
        )
      end

      context 'when entry_status is raw' do
        let(:entry_status) { :raw }

        it 'add ingestion job to queue and sets entry status to `migrating`' do
          expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
          expect(call).to eq(200)
          expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
          expect(file.lex_entry.reload.status).to eq('migrating')
        end
      end

      context 'when entry_status is error' do
        let(:entry_status) { :error }

        before do
          file.update!(error_message: 'Some error')
        end

        it 'resets error message and add ingestion job to queue and sets entry status to `migrating`' do
          expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
          expect(call).to eq(200)
          expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
          expect(file.lex_entry.reload.status).to eq('migrating')
          expect(file.reload.error_message).to be_nil
        end
      end

      context 'when entry_status is not error or raw' do
        let(:entry_status) { (LexEntry.statuses.keys - %w(raw error)).sample }

        it 'does not queue job and simply re-renders tr' do
          expect { call }.not_to(change { Lexicon::IngestFile.jobs.size })
          expect(call).to eq(200)
          expect(file.lex_entry.reload.status).to eq(entry_status)
        end
      end
    end
  end
end
