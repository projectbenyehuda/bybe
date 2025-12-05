# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

describe '/lexicon/files' do
  describe '#index' do
    subject(:call) { get '/lex/files' }

    before do
      create_list(:lex_file, 2, :person, status: :classified)
      create_list(:lex_file, 2, :person, status: :ingested)
      create_list(:lex_file, 2, :publication, status: :classified)
      create_list(:lex_file, 2, :publication, status: :ingested)
    end

    it 'renders successfully' do
      expect(call).to eq(200)
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
