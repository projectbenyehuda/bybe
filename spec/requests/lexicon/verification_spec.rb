# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification', type: :request do
  before do
    login_as_lexicon_editor
  end

  describe 'GET /lex/verification/:id (show) - copyrighted auto-copy from Authority' do
    context 'when LexPerson has no copyrighted value and has a public_domain Authority' do
      let(:authority) { create(:authority, intellectual_property: :public_domain) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to false (public domain)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be false
      end
    end

    context 'when LexPerson has no copyrighted value and has a copyrighted Authority' do
      let(:authority) { create(:authority, intellectual_property: :copyrighted) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to true' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and Authority has orphan IP' do
      let(:authority) { create(:authority, intellectual_property: :orphan) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to true (non-public-domain defaults to copyrighted)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and Authority has permission_for_all IP' do
      let(:authority) { create(:authority, intellectual_property: :permission_for_all) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to true (non-public-domain defaults to copyrighted)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson already has copyrighted set' do
      let(:authority) { create(:authority, intellectual_property: :public_domain) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: true, authority_id: authority.id)
        e.start_verification!('editor@example.com')
        e
      end

      it 'does not overwrite the existing copyrighted value' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and no Authority' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: nil, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'leaves copyrighted as nil' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be_nil
      end
    end

    context 'when LexPerson has no copyrighted value and died fewer than 71 years ago' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        recent_death_year = Time.zone.today.year - 50
        e.lex_item.update_columns(copyrighted: nil, authority_id: nil, deathdate: "#{recent_death_year}-01-01")
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to true (still within copyright)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and died exactly 70 years ago (boundary: last copyrighted year)' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        death_year = Time.zone.today.year - 70
        e.lex_item.update_columns(copyrighted: nil, authority_id: nil, deathdate: "#{death_year}-01-01")
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to true (70 < 71)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and died exactly 71 years ago (boundary: first public domain year)' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        death_year = Time.zone.today.year - 71
        e.lex_item.update_columns(copyrighted: nil, authority_id: nil, deathdate: "#{death_year}-01-01")
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to false (71 is not < 71)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be false
      end
    end

    context 'when LexPerson has no copyrighted value and died 71 or more years ago' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        old_death_year = Time.zone.today.year - 80
        e.lex_item.update_columns(copyrighted: nil, authority_id: nil, deathdate: "#{old_death_year}-01-01")
        e.start_verification!('editor@example.com')
        e
      end

      it 'sets copyrighted to false (public domain)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be false
      end
    end

    context 'when LexPerson has no copyrighted value, a known death year, and an Authority with conflicting IP' do
      let(:authority) { create(:authority, intellectual_property: :public_domain) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        recent_death_year = Time.zone.today.year - 50
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id,
                                  deathdate: "#{recent_death_year}-01-01")
        e.start_verification!('editor@example.com')
        e
      end

      it 'uses death year over Authority (sets copyrighted to true)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end
    end

    context 'when LexPerson has no copyrighted value and no death year but has an Authority' do
      let(:authority) { create(:authority, intellectual_property: :public_domain) }
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil, authority_id: authority.id, deathdate: nil)
        e.start_verification!('editor@example.com')
        e
      end

      it 'falls back to Authority (sets copyrighted to false for public_domain)' do
        get "/lex/verification/#{entry.id}"

        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be false
      end
    end
  end

  describe 'PATCH /lex/verification/:id/update_section' do
    context 'when updating the title section to change copyrighted status' do
      let(:entry) do
        e = create(:lex_entry, :person, status: :verifying)
        e.lex_item.update_columns(copyrighted: nil)
        e.start_verification!('editor@example.com')
        e
      end
      let(:url) { "/lex/verification/#{entry.id}/update_section" }

      it 'saves copyrighted=true when selected' do
        patch url,
              params: { section: 'title', lex_person: { copyrighted: 'true' } },
              as: :json

        expect(response).to have_http_status(:success)
        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be true
      end

      it 'saves copyrighted=false when public domain is selected' do
        patch url,
              params: { section: 'title', lex_person: { copyrighted: 'false' } },
              as: :json

        expect(response).to have_http_status(:success)
        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be false
      end

      it 'keeps copyrighted=nil when blank/unknown is selected' do
        patch url,
              params: { section: 'title', lex_person: { copyrighted: '' } },
              as: :json

        expect(response).to have_http_status(:success)
        entry.lex_item.reload
        expect(entry.lex_item.copyrighted).to be_nil
      end
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
        patch url, params: { path: 'attachments', verified: 'true' }, as: :json

        # Verify all collection items (citations, links, works are empty for this entry)
        entry.reload
        expect(entry.verification_percentage).to eq(100)
        expect(entry.verification_complete?).to be true
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
        expect(json_response['error']).to eq('Attachment not found')
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
    # tsifroni.php has 3 work bullets, 0 citation bullets, 0 link bullets
    let(:fixture_path) { Rails.root.join('spec/data/lexicon/tsifroni.php').to_s }

    let(:entry) do
      e = create(:lex_entry, :person, status: :verifying)
      e.start_verification!('editor@example.com')
      e
    end

    context 'with a lex_file pointing to tsifroni.php (3 work bullets)' do
      before do
        lex_file = create(:lex_file, :person, lex_entry: entry)
        lex_file.update_columns(full_path: fixture_path)
      end

      context 'when migrated works count matches PHP file (3 works == 3 bullets)' do
        before { 3.times { create(:lex_person_work, person: entry.lex_item) } }

        it 'does not show works count mismatch warning' do
          get "/lex/verification/#{entry.id}"

          expect(response.body).not_to include(
            I18n.t('lexicon.verification.sections.count_mismatch', php_count: 3, migrated_count: 3)
          )
        end
      end

      context 'when migrated works count does not match PHP file (0 works vs 3 bullets)' do
        it 'shows works count mismatch warning' do
          get "/lex/verification/#{entry.id}"

          expect(response.body).to include(
            I18n.t('lexicon.verification.sections.count_mismatch', php_count: 3, migrated_count: 0)
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
end
