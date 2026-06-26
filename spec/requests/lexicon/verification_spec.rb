# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification', type: :request do
  before do
    login_as_lexicon_editor
  end

  describe 'PATCH /lex/verification/:id/update_section – external_identifiers' do
    let(:entry) do
      e = create(:lex_entry, :person,
                 status: :verifying,
                 external_identifiers: { 'viaf' => '123', 'lc' => 'n456' })
      e.start_verification!('editor@example.com')
      e
    end
    let(:url) { "/lex/verification/#{entry.id}/update_section" }

    it 'saves updated external_identifiers' do
      patch url,
            params: { section: 'external_identifiers',
                      external_identifiers: { viaf: '999', lc: 'n456' } },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.external_identifiers['viaf']).to eq('999')
      expect(entry.external_identifiers['lc']).to eq('n456')
    end

    it 'removes an identifier when its value is blank' do
      patch url,
            params: { section: 'external_identifiers',
                      external_identifiers: { viaf: '', lc: 'n456' } },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.external_identifiers).not_to have_key('viaf')
      expect(entry.external_identifiers['lc']).to eq('n456')
    end

    it 'marks the section verified when mark_verified is set' do
      patch url,
            params: { section: 'external_identifiers',
                      external_identifiers: { viaf: '123', lc: 'n456' },
                      mark_verified: '1' },
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['success']).to be true
      entry.reload
      expect(entry.verification_progress.dig('checklist', 'external_identifiers', 'verified')).to be true
    end

    it 'sets external_identifiers to nil when all values are blank' do
      patch url,
            params: { section: 'external_identifiers',
                      external_identifiers: { viaf: '', lc: '' } },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.external_identifiers).to be_nil
    end
  end

  describe 'PATCH /lex/verification/:id/update_section – date_of_manual_update' do
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying, date_of_manual_update: '12 בינואר 2024')
      e.start_verification!('editor@example.com')
      e
    end
    let(:url) { "/lex/verification/#{entry.id}/update_section" }

    it 'saves the updated date_of_manual_update value' do
      patch url,
            params: { section: 'date_of_manual_update',
                      entry_date_of_manual_update: '15 במרץ 2024' },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.date_of_manual_update).to eq('15 במרץ 2024')
    end

    it 'clears date_of_manual_update when blank value is submitted' do
      patch url,
            params: { section: 'date_of_manual_update',
                      entry_date_of_manual_update: '' },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.date_of_manual_update).to be_nil
    end

    it 'marks the section verified when mark_verified is set' do
      patch url,
            params: { section: 'date_of_manual_update',
                      entry_date_of_manual_update: '12 בינואר 2024',
                      mark_verified: '1' },
            as: :json

      expect(response).to have_http_status(:success)
      entry.reload
      expect(entry.verification_progress.dig('checklist', 'date_of_manual_update', 'verified')).to be true
    end
  end

  describe 'PATCH /lex/verification/:id/update_checklist' do
    context 'when verifying the title section for a LexPerson' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.start_verification!('editor@example.com')
        e
      end
      let(:url) { "/lex/verification/#{entry.id}/update_checklist" }

      it 'also marks life_years as verified when title is verified' do
        patch url, params: { path: 'title', verified: 'true' }, as: :json

        expect(response).to have_http_status(:success)
        entry.reload
        expect(entry.verification_progress.dig('checklist', 'title', 'verified')).to be true
        expect(entry.verification_progress.dig('checklist', 'life_years', 'verified')).to be true
      end

      it 'also unverifies life_years when title is unverified' do
        # First verify both
        entry.update_checklist_item('title', true)
        entry.update_checklist_item('life_years', true)

        patch url, params: { path: 'title', verified: 'false' }, as: :json

        expect(response).to have_http_status(:success)
        entry.reload
        expect(entry.verification_progress.dig('checklist', 'title', 'verified')).to be false
        expect(entry.verification_progress.dig('checklist', 'life_years', 'verified')).to be false
      end

      it 'allows verification_percentage to reach 100 when all items are verified via quickVerify' do
        # Simulate user clicking quickVerify on every section (title path covers life_years)
        patch url, params: { path: 'title', verified: 'true' }, as: :json
        patch url, params: { path: 'bio', verified: 'true' }, as: :json
        patch url, params: { path: 'external_identifiers', verified: 'true' }, as: :json
        patch url, params: { path: 'attachments', verified: 'true' }, as: :json
        patch url, params: { path: 'date_of_manual_update', verified: 'true' }, as: :json

        # Verify all collection items (citations, links, works are empty for this entry)
        entry.reload
        expect(entry.verification_percentage).to eq(100)
        expect(entry.verification_complete?).to be true
      end

      it 'persists date_of_manual_update verification to the database' do
        patch url, params: { path: 'date_of_manual_update', verified: 'true' }, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['success']).to be true
        entry.reload
        expect(entry.verification_progress.dig('checklist', 'date_of_manual_update', 'verified')).to be true
      end

      it 'unverifies date_of_manual_update when verified: false is sent' do
        entry.update_checklist_item('date_of_manual_update', true)

        patch url, params: { path: 'date_of_manual_update', verified: 'false' }, as: :json

        expect(response).to have_http_status(:success)
        entry.reload
        expect(entry.verification_progress.dig('checklist', 'date_of_manual_update', 'verified')).to be false
      end
    end
  end

  describe 'PATCH /lex/verification/:id/set_profile_image' do
    let(:entry) { create(:lex_entry) }
    let(:url) { "/lex/verification/#{entry.id}/set_profile_image" }

    before do
      # Attach some test images
      entry.attachments.attach(
        io: StringIO.new('test image 1'),
        filename: 'test1.jpg',
        content_type: 'image/jpeg'
      )
      entry.attachments.attach(
        io: StringIO.new('test image 2'),
        filename: 'test2.jpg',
        content_type: 'image/jpeg'
      )
    end

    context 'when setting a valid attachment as profile image' do
      it 'sets the profile_image_id' do
        attachment = entry.attachments.first
        expect(entry.profile_image_id).to be_nil # Verify starts as nil

        patch url, params: { attachment_id: attachment.id }, as: :json

        expect(response).to have_http_status(:success)

        # Verify database was actually updated
        entry.reload
        expect(entry.profile_image_id).to eq(attachment.id)
        expect(entry.profile_image).to eq(attachment)

        json_response = response.parsed_body
        expect(json_response['success']).to be true
        expect(json_response['profile_image_id']).to eq(attachment.id)
      end

      it 'can change the profile image to a different attachment' do
        first_attachment = entry.attachments.first
        second_attachment = entry.attachments.second

        # Set first attachment
        patch url, params: { attachment_id: first_attachment.id }, as: :json
        expect(entry.reload.profile_image_id).to eq(first_attachment.id)

        # Change to second attachment
        patch url, params: { attachment_id: second_attachment.id }, as: :json
        expect(response).to have_http_status(:success)
        expect(entry.reload.profile_image_id).to eq(second_attachment.id)
      end
    end

    context 'when attachment does not belong to entry' do
      it 'returns not found error' do
        other_entry = create(:lex_entry)
        other_entry.attachments.attach(
          io: StringIO.new('other image'),
          filename: 'other.jpg',
          content_type: 'image/jpeg'
        )
        other_attachment = other_entry.attachments.first

        patch url, params: { attachment_id: other_attachment.id }, as: :json

        expect(response).to have_http_status(:not_found)

        json_response = response.parsed_body
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq(I18n.t('lexicon.verification.messages.attachment_not_found'))
      end
    end

    context 'when attachment_id is invalid' do
      it 'returns not found error' do
        patch url, params: { attachment_id: 99_999 }, as: :json

        expect(response).to have_http_status(:not_found)

        json_response = response.parsed_body
        expect(json_response['success']).to be false
      end
    end
  end

  describe 'GET /lex/verification/:id - PHP source file count mismatch warnings' do
    # tsifroni.php has 3 EMPTY (whitespace-only) work bullets — 0 non-empty works.
    # Empty <li> items are excluded from the count to match migration behaviour.
    let(:fixture_path) { Rails.root.join('spec/fixtures/files/lexicon/tsifroni.php').to_s }

    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying)
      e.start_verification!('editor@example.com')
      e
    end

    context 'with a lex_file pointing to tsifroni.php (0 non-empty work bullets)' do
      before do
        lex_file = create(:lex_file, :person, lex_entry: entry)
        lex_file.update_columns(full_path: fixture_path)
      end

      context 'when migrated works count matches PHP file (0 works == 0 non-empty bullets)' do
        it 'does not show works count mismatch warning even though PHP has 3 empty <li> items' do
          get "/lex/verification/#{entry.id}"

          expect(response.body).not_to include('count_mismatch')
        end
      end

      context 'when migrated works count does not match PHP file (1 DB work vs 0 non-empty bullets)' do
        before { create(:lex_person_work, person: entry.lex_item) }

        it 'shows works count mismatch warning' do
          get "/lex/verification/#{entry.id}"

          expect(response.body).to include(
            I18n.t('lexicon.verification.sections.count_mismatch', php_count: 0, migrated_count: 1)
          )
        end
      end
    end

    context 'when there is no lex_file attached to the entry' do
      it 'does not show any count mismatch warning' do
        get "/lex/verification/#{entry.id}"

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('count_mismatch')
      end
    end
  end

  describe 'DELETE /lex/verification/:id/remove_attachment' do
    let(:entry) { create(:lex_entry) }
    let(:url) { "/lex/verification/#{entry.id}/remove_attachment" }

    before do
      entry.attachments.attach(
        io: StringIO.new('test image 1'),
        filename: 'test1.jpg',
        content_type: 'image/jpeg'
      )
      entry.attachments.attach(
        io: StringIO.new('test image 2'),
        filename: 'test2.jpg',
        content_type: 'image/jpeg'
      )
    end

    context 'when removing a valid attachment' do
      it 'removes the attachment and its blob from storage' do
        attachment = entry.attachments.first
        blob = attachment.blob

        delete url, params: { attachment_id: attachment.id }, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['success']).to be true

        # Attachment record is removed from entry
        entry.reload
        expect(entry.attachments.map(&:id)).not_to include(attachment.id)

        # Blob is also purged
        expect(ActiveStorage::Blob.exists?(blob.id)).to be false
      end

      it 'clears profile_image_id when removing the profile image attachment' do
        attachment = entry.attachments.first
        entry.update!(profile_image_id: attachment.id)

        delete url, params: { attachment_id: attachment.id }, as: :json

        expect(response).to have_http_status(:success)
        expect(entry.reload.profile_image_id).to be_nil
      end

      it 'leaves other attachments untouched' do
        attachment = entry.attachments.first
        other_attachment = entry.attachments.second

        delete url, params: { attachment_id: attachment.id }, as: :json

        expect(entry.reload.attachments.map(&:id)).to include(other_attachment.id)
      end
    end

    context 'when attachment does not belong to entry' do
      it 'returns not found error' do
        other_entry = create(:lex_entry)
        other_entry.attachments.attach(
          io: StringIO.new('other image'),
          filename: 'other.jpg',
          content_type: 'image/jpeg'
        )
        other_attachment = other_entry.attachments.first

        delete url, params: { attachment_id: other_attachment.id }, as: :json

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['success']).to be false
      end
    end

    context 'when attachment_id is invalid' do
      it 'returns not found error' do
        delete url, params: { attachment_id: 99_999 }, as: :json

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['success']).to be false
      end
    end
  end

  describe 'POST /lex/verification/:id/mark_verified' do
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying)
      e.start_verification!('editor@example.com')
      e
    end
    let(:url) { "/lex/verification/#{entry.id}/mark_verified" }

    context 'when verification is complete' do
      before do
        # mark_verified! guards on verification_complete?, so check every checklist item.
        # A bare person entry has no works/citations/links items.
        entry.verification_progress['checklist'].each_key do |key|
          next if %w(works citations links).include?(key)

          entry.update_checklist_item(key, true)
        end
        entry.reload
      end

      it "redirects to the entry's public view with a verified flash" do
        # Precondition: the fixture must be complete, else mark_verified! raises.
        expect(entry.verification_complete?).to be(true)

        post url

        expect(response).to redirect_to(lexicon_entry_path(entry))
        expect(flash[:notice]).to eq(I18n.t('lexicon.verification.messages.entry_verified_public'))
      end

      it 'marks the entry as published' do
        expect(entry.verification_complete?).to be(true)

        post url

        expect(entry.reload).to be_status_published
      end
    end

    context 'when verification is not complete' do
      it 'redirects back to the workbench with the raised error' do
        post url

        expect(response).to redirect_to(lexicon_verification_path(entry))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET /lex/verification/queue' do
    context 'when filtering by max_items' do
      let!(:small_entry) { create(:lex_entry, :person, status: :draft, migration_item_count: 10) }
      let!(:large_entry) { create(:lex_entry, :person, status: :draft, migration_item_count: 100) }
      let!(:nil_entry)   { create(:lex_entry, :person, status: :draft, migration_item_count: nil) }

      it 'returns only entries with migration_item_count <= max_items' do
        get '/lex/verification/queue', params: { max_items: '30' }
        entry_ids = assigns(:entries).map(&:id)
        expect(entry_ids).to include(small_entry.id)
        expect(entry_ids).not_to include(large_entry.id, nil_entry.id)
      end

      it 'returns all entries when max_items is blank' do
        get '/lex/verification/queue'
        entry_ids = assigns(:entries).map(&:id)
        expect(entry_ids).to include(small_entry.id, large_entry.id, nil_entry.id)
      end

      it 'ignores a non-numeric max_items and returns all entries' do
        get '/lex/verification/queue', params: { max_items: 'abc' }
        entry_ids = assigns(:entries).map(&:id)
        expect(entry_ids).to include(small_entry.id, large_entry.id, nil_entry.id)
      end
    end

    context 'when sorting by migration_item_count' do
      let!(:entry_low) { create(:lex_entry, :person, status: :draft, migration_item_count: 5) }
      let!(:entry_high) { create(:lex_entry, :person, status: :draft, migration_item_count: 50) }
      let!(:entry_mid)  { create(:lex_entry, :person, status: :draft, migration_item_count: 20) }

      it 'sorts ascending when direction=asc' do
        get '/lex/verification/queue', params: { sort: 'migration_item_count', direction: 'asc' }
        ids = assigns(:entries).map(&:id)
        expect(ids).to eq([entry_low.id, entry_mid.id, entry_high.id])
      end

      it 'sorts descending when direction=desc' do
        get '/lex/verification/queue', params: { sort: 'migration_item_count', direction: 'desc' }
        ids = assigns(:entries).map(&:id)
        expect(ids).to eq([entry_high.id, entry_mid.id, entry_low.id])
      end
    end

    it 'auto-refreshes the page periodically' do
      get '/lex/verification/queue'

      expect(response.body).to include('window.location.reload()')
    end

    context 'with a re-migrate button' do
      let!(:verifying_file) { create(:lex_file, :person, entry_status: :verifying) }
      let!(:escalated_file) { create(:lex_file, :person, entry_status: :escalated) }
      let!(:draft_file) { create(:lex_file, :person, entry_status: :draft) }
      let!(:error_file) { create(:lex_file, :person, entry_status: :error) }

      it 'shows the re-migrate button for redo-eligible entries' do
        get '/lex/verification/queue'

        expect(response.body).to include(redo_migration_lexicon_file_path(verifying_file))
        expect(response.body).to include(redo_migration_lexicon_file_path(escalated_file))
        expect(response.body).to include(redo_migration_lexicon_file_path(draft_file))
      end

      it 'does not show the re-migrate button for entries in error status' do
        get '/lex/verification/queue'

        expect(response.body).not_to include(redo_migration_lexicon_file_path(error_file))
      end
    end

    context 'with locked entries' do
      let(:other_editor) do
        user = create(:user, editor: true)
        ListItem.create!(listkey: 'edit_lexicon', item: user)
        user
      end

      describe 'my-locked section' do
        context 'when the current editor has a locked entry' do
          let!(:mine) do
            entry = create(:lex_entry, :person, status: :draft)
            entry.update_columns(locked_at: 5.minutes.ago, locked_by_user_id: create_lexicon_editor.id)
            entry
          end

          it 'shows the "Entries locked by me" heading' do
            get '/lex/verification/queue'
            expect(response.body).to include(I18n.t('lexicon.verification.queue.my_locked_title'))
          end

          it 'excludes the locked entry from the other-entries section (appears exactly once)' do
            get '/lex/verification/queue'
            expect(response.body.scan(mine.title).size).to eq(1)
          end
        end

        it 'omits the my-locked heading when no entries are locked by the current editor' do
          get '/lex/verification/queue'
          expect(response.body).not_to include(I18n.t('lexicon.verification.queue.my_locked_title'))
        end
      end

      describe 'locked-by-others section' do
        context 'when another editor has a locked entry' do
          let!(:theirs) do
            entry = create(:lex_entry, :person, status: :draft)
            entry.update_columns(locked_at: 5.minutes.ago, locked_by_user_id: other_editor.id)
            entry
          end

          it 'shows the "Entries locked by other editors" heading' do
            get '/lex/verification/queue'
            expect(response.body).to include(I18n.t('lexicon.verification.queue.locked_by_others_title'))
          end

          it "shows the locking editor's name in the row" do
            get '/lex/verification/queue'
            expect(response.body).to include(I18n.t('lockable.locked_by_human', name: other_editor.name))
          end

          it 'excludes the locked entry from the other-entries section (appears exactly once)' do
            get '/lex/verification/queue'
            expect(response.body.scan(theirs.title).size).to eq(1)
          end
        end

        it 'omits the locked-by-others heading when no entries are locked by other editors' do
          get '/lex/verification/queue'
          expect(response.body).not_to include(I18n.t('lexicon.verification.queue.locked_by_others_title'))
        end
      end

      describe 'expired locks' do
        let!(:expired) do
          entry = create(:lex_entry, :person, status: :draft)
          entry.update_columns(
            locked_at: (Lockable::LOCK_TIMEOUT_IN_SECONDS + 60).seconds.ago,
            locked_by_user_id: create_lexicon_editor.id
          )
          entry
        end

        it 'treats an expired lock as unlocked (no my-locked heading shown)' do
          get '/lex/verification/queue'
          expect(response.body).not_to include(I18n.t('lexicon.verification.queue.my_locked_title'))
        end

        it 'includes an expired-lock entry in the other-entries section' do
          get '/lex/verification/queue'
          expect(response.body).to include(expired.title)
        end
      end

      describe 'filter consistency across sections' do
        let!(:draft_mine) do
          entry = create(:lex_entry, :person, status: :draft)
          entry.update_columns(locked_at: 5.minutes.ago, locked_by_user_id: create_lexicon_editor.id)
          entry
        end

        let!(:verifying_mine) do
          entry = create(:lex_entry, :person, status: :verifying)
          entry.update_columns(locked_at: 5.minutes.ago, locked_by_user_id: create_lexicon_editor.id)
          entry
        end

        it 'status filter applies to the my-locked section' do
          get '/lex/verification/queue', params: { status: 'draft' }
          expect(response.body).to include(draft_mine.title)
          expect(response.body).not_to include(verifying_mine.title)
        end

        context 'with a publication also locked by me' do
          let!(:pub_mine) do
            entry = create(:lex_entry, :publication, status: :draft)
            entry.update_columns(locked_at: 5.minutes.ago, locked_by_user_id: create_lexicon_editor.id)
            entry
          end

          it 'type filter applies to the my-locked section' do
            get '/lex/verification/queue', params: { type: 'LexPerson' }
            expect(response.body).to include(draft_mine.title)
            expect(response.body).not_to include(pub_mine.title)
          end
        end
      end
    end
  end

  describe 'POST /lex/verification/:id/escalate' do
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying)
      e.start_verification!('editor@example.com')
      e
    end
    let(:url) { "/lex/verification/#{entry.id}/escalate" }

    it 'sets entry status to escalated' do
      post url, params: { overall_notes: 'needs expert review' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['success']).to be true
      expect(entry.reload).to be_status_escalated
    end

    it 'saves the submitted overall_notes' do
      post url, params: { overall_notes: 'needs expert review' }, as: :json

      expect(entry.reload.verification_progress['overall_notes']).to eq('needs expert review')
    end

    it 'clears overall_notes when blank is submitted' do
      entry.update!(verification_progress: entry.verification_progress.merge('overall_notes' => 'old notes'))

      post url, params: { overall_notes: '' }, as: :json

      expect(entry.reload.verification_progress['overall_notes']).to eq('')
    end

    it 'returns a redirect_url pointing to the verification queue' do
      post url, params: {}, as: :json

      expect(response.parsed_body['redirect_url']).to eq('/lex/verification/queue')
    end
  end

  describe 'GET /lex/verification/:id/escalate_form' do
    let(:entry) { create(:lex_entry, :person, status: :verifying) }

    before do
      entry.start_verification!('editor@example.com')
      entry.update!(verification_progress: entry.verification_progress.merge('overall_notes' => 'some existing notes'))
    end

    it 'returns the escalation form partial' do
      get "/lex/verification/#{entry.id}/escalate_form"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('lexicon.verification.show.escalate'))
      expect(response.body).to include('some existing notes')
    end
  end

  describe 'GET /lex/verification/:id (show) - escalated entry does not reset progress' do
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying)
      e.start_verification!('editor@example.com')
      e.update!(status: :escalated,
                verification_progress: e.verification_progress.merge('overall_notes' => 'escalation note'))
      e
    end

    it 'does not reinitialize verification progress for an escalated entry' do
      get "/lex/verification/#{entry.id}"

      expect(entry.reload.verification_progress['overall_notes']).to eq('escalation note')
      expect(entry.reload).to be_status_escalated
    end
  end

  describe 'GET /lex/verification/:id (show) - citation and link edit buttons use reloadPage' do
    let(:person) { create(:lex_person) }
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying, lex_item: person)
      e.start_verification!('editor@example.com')
      e
    end
    let!(:citation) { create(:lex_citation, person: person, title: 'Test Citation', from_publication: 'Test Pub') }
    let!(:link) { create(:lex_link, item: person) }

    it 'citation edit button callback uses reloadPage() not location.reload()' do
      get "/lex/verification/#{entry.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/lex/citations/#{citation.id}/edit")
      expect(response.body).to include('reloadPage()')
      expect(response.body).not_to include('location.reload()')
    end

    it 'link edit button callback uses reloadPage() not location.reload()' do
      get "/lex/verification/#{entry.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/lex/links/#{link.id}/edit")
      expect(response.body).to include('reloadPage()')
      expect(response.body).not_to include('location.reload()')
    end
  end

  describe 'GET /lex/verification/:id (show) - per-work cards' do
    let(:person) { create(:lex_person) }
    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying, lex_item: person)
      e.start_verification!('editor@example.com')
      e
    end
    let!(:work1) { create(:lex_person_work, person: person, title: 'First Work', work_type: 'original', seqno: 1) }
    let!(:work2) { create(:lex_person_work, person: person, title: 'Second Work', work_type: 'original', seqno: 2) }

    before do
      entry.add_work_to_checklist!(work1.id)
      entry.add_work_to_checklist!(work2.id)
    end

    it 'renders individual work cards instead of a single works section' do
      get "/lex/verification/#{entry.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("work-#{work1.id}")
      expect(response.body).to include("work-#{work2.id}")
      expect(response.body).to include('work-card')
    end

    it 'renders per-work edit buttons linking to individual work edit paths' do
      get "/lex/verification/#{entry.id}"

      expect(response.body).to include("/lex/works/#{work1.id}/edit")
      expect(response.body).to include("/lex/works/#{work2.id}/edit")
    end

    it 'renders per-work verify buttons with correct checklist paths' do
      get "/lex/verification/#{entry.id}"

      expect(response.body).to include("works.items.#{work1.id}")
      expect(response.body).to include("works.items.#{work2.id}")
    end

    it 'shows verified count in the works badge' do
      # Mark first work as verified
      entry.update_checklist_item("works.items.#{work1.id}", true)

      get "/lex/verification/#{entry.id}"

      expect(response.body).to include('1/2')
    end
  end
end
