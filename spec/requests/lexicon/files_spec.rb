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
        create_list(:lex_file, 2, :person, status: :classified, entry_status: :raw)
        create_list(:lex_file, 2, :person, status: :ingested, entry_status: :error)
        create_list(:lex_file, 2, :publication, status: :classified, entry_status: :draft)
        create_list(:lex_file, 2, :publication, status: :ingested, entry_status: :published)
      end

      it 'renders successfully and shows default statuses selection' do
        call
        expect(call).to eq(200)
        expect(file_ids.size).to eq(6)
      end
    end

    context 'when entry has verifying status but no lex_item (stuck after NFS error)' do
      let(:params) { { entry_statuses: ['verifying'] } }

      let!(:stuck_file) do
        file = create(:lex_file, :person, status: :classified, entry_status: :raw,
                                          error_message: 'No such file or directory @ rb_sysopen - /lexicon/00044.php')
        file.lex_entry.update_columns(status: LexEntry.statuses[:verifying])
        file
      end

      it 'renders the redo_migration button so the entry is not stuck' do
        expect(stuck_file.lex_entry.lex_item).to be_nil # entry_status: :raw factory trait guarantees nil lex_item
        call
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(redo_migration_lexicon_file_path(stuck_file))
      end
    end

    context 'when filtering applied' do
      context 'when filtering by title' do
        let!(:file1) do
          create(
            :lex_file,
            :person,
            status: :classified,
            entry_status: :raw,
            title: 'Abraham Lincoln'
          )
        end

        let!(:file2) do
          create(
            :lex_file,
            :person,
            status: :classified,
            entry_status: :raw,
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
            entry_status: :raw,
            title: 'Test Person',
            fname: '00003.php'
          )
        end

        let!(:publication_file) do
          create(
            :lex_file,
            :publication,
            status: :classified,
            entry_status: :raw,
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
            entry_status: :raw,
            title: 'Test Person'
          )
        end

        let!(:publication_file) do
          create(
            :lex_file,
            :publication,
            status: :classified,
            entry_status: :raw,
            title: 'Test Publication'
          )
        end

        let(:params) { { entrytype: 'person', title: 'Test' } }

        it 'applies both filters' do
          call
          expect(file_ids).to contain_exactly(person_file.id)
        end
      end

      context 'when filtering by entry_statuses' do
        let!(:raw_file) { create(:lex_file, :person, entry_status: :raw) }
        let!(:migrating_file) { create(:lex_file, :person, entry_status: :migrating) }
        let!(:error_file) { create(:lex_file, :person, entry_status: :error) }
        let!(:draft_file) { create(:lex_file, :person, entry_status: :draft) }
        let!(:verifying_file) { create(:lex_file, :person, entry_status: :verifying) }
        let!(:verified_file) { create(:lex_file, :person, entry_status: :verified) }

        context 'when a single status is requested' do
          let(:params) { { entry_statuses: ['raw'] } }

          it 'returns only files with that entry status' do
            call
            expect(file_ids).to contain_exactly(raw_file.id)
          end
        end

        context 'when multiple statuses are requested' do
          let(:params) { { entry_statuses: %w(raw error) } }

          it 'returns files matching any of the specified statuses' do
            call
            expect(file_ids).to contain_exactly(raw_file.id, error_file.id)
          end
        end

        context 'when no entry_statuses param is provided (default)' do
          let(:params) { {} }

          it 'defaults to raw, migrating, error, draft and verifying statuses' do
            call
            expect(file_ids).to contain_exactly(
              raw_file.id, error_file.id, migrating_file.id, draft_file.id, verifying_file.id
            )
          end
        end
      end
    end

    context 'with locked entries' do
      subject(:call) { get '/lex/files' }

      let(:current_user) { login_as_lexicon_editor }
      let(:other_user) { create(:user) }

      let!(:my_locked) { create(:lex_file, :person, entry_status: :verifying) }
      let!(:other_locked) { create(:lex_file, :person, entry_status: :verifying) }
      let!(:unlocked) { create(:lex_file, :person, entry_status: :draft) }

      before do
        my_locked.lex_entry.obtain_lock?(current_user)
        other_locked.lex_entry.obtain_lock?(other_user)
      end

      it 'assigns my locked files to @my_locked_files' do
        call
        expect(assigns(:my_locked_files).map(&:id)).to contain_exactly(my_locked.id)
      end

      it "assigns others' locked files to @locked_by_others_files" do
        call
        expect(assigns(:locked_by_others_files).map(&:id)).to contain_exactly(other_locked.id)
      end

      it 'excludes locked files from the main @lex_files list' do
        call
        expect(assigns(:lex_files).map(&:id)).to contain_exactly(unlocked.id)
      end

      it 'shows an unlock button only for files locked by me' do
        call
        expect(response.body).to include(I18n.t('lexicon.files.index.my_locked_title'))
        expect(response.body).to include(unlock_lexicon_entry_path(my_locked.lex_entry))
        expect(response.body).not_to include(unlock_lexicon_entry_path(other_locked.lex_entry))
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

  describe 'POST /redo_migration' do
    subject(:call) { post "/lex/files/#{file.id}/redo_migration", xhr: true }

    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    let!(:file) do
      create(
        :lex_file,
        :person,
        status: :ingested,
        entry_status: entry_status
      )
    end

    context 'when entry_status is draft' do
      let(:entry_status) { :draft }

      it 'resets the lex_item, queues the job, and sets entry status to migrating' do
        expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
        expect(call).to eq(200)
        expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
        expect(file.lex_entry.reload.status).to eq('migrating')
        expect(file.lex_entry.lex_item).to be_nil
        expect(file.reload.status).to eq('classified')
      end
    end

    context 'when entry_status is verifying' do
      let(:entry_status) { :verifying }

      it 'resets the lex_item, queues the job, and sets entry status to migrating' do
        expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
        expect(call).to eq(200)
        expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
        expect(file.lex_entry.reload.status).to eq('migrating')
        expect(file.lex_entry.lex_item).to be_nil
        expect(file.reload.status).to eq('classified')
      end
    end

    context 'when entry_status is escalated' do
      let(:entry_status) { :escalated }

      it 'resets the lex_item, queues the job, and sets entry status to migrating' do
        expect { call }.to change { Lexicon::IngestFile.jobs.size }.by(1)
        expect(call).to eq(200)
        expect(Lexicon::IngestFile.jobs.last['args']).to eq([file.id])
        expect(file.lex_entry.reload.status).to eq('migrating')
        expect(file.lex_entry.lex_item).to be_nil
        expect(file.reload.status).to eq('classified')
      end
    end

    context 'when entry_status is not draft, verifying, or escalated' do
      let(:entry_status) { LexEntry.statuses.keys.find { |status| %w(draft verifying escalated).exclude?(status) } }

      it 'does not queue job and simply re-renders tr' do
        expect { call }.not_to(change { Lexicon::IngestFile.jobs.size })
        expect(call).to eq(200)
      end
    end
  end

  describe 'locking when starting a migration' do
    before { Sidekiq::Testing.fake! }
    after { Sidekiq::Worker.clear_all }

    let(:current_user) { login_as_lexicon_editor }
    let(:other_user) { create(:user) }

    describe 'POST /migrate' do
      let!(:file) { create(:lex_file, :person, status: :classified, entry_status: :raw) }

      it 'locks the entry for the current user' do
        current_user # stub current_user before the request
        post "/lex/files/#{file.id}/migrate", xhr: true
        expect(file.lex_entry.reload).to be_locked
        expect(file.lex_entry.locked_by_user).to eq(current_user)
      end

      context 'when the entry is already locked by another user' do
        before { file.lex_entry.obtain_lock?(other_user) }

        it 'does not start the migration' do
          current_user
          expect { post "/lex/files/#{file.id}/migrate", xhr: true }
            .not_to(change { Lexicon::IngestFile.jobs.size })
          expect(file.lex_entry.reload.status).to eq('raw')
          expect(file.lex_entry.locked_by_user).to eq(other_user)
        end
      end
    end

    describe 'POST /redo_migration' do
      let!(:file) { create(:lex_file, :person, status: :ingested, entry_status: :draft) }

      it 'locks the entry for the current user' do
        current_user
        post "/lex/files/#{file.id}/redo_migration", xhr: true
        expect(file.lex_entry.reload).to be_locked
        expect(file.lex_entry.locked_by_user).to eq(current_user)
      end

      context 'when the entry is already locked by another user' do
        before { file.lex_entry.obtain_lock?(other_user) }

        it 'does not redo the migration' do
          current_user
          expect { post "/lex/files/#{file.id}/redo_migration", xhr: true }
            .not_to(change { Lexicon::IngestFile.jobs.size })
          expect(file.lex_entry.reload.status).to eq('draft')
          expect(file.lex_entry.locked_by_user).to eq(other_user)
        end
      end
    end
  end
end
