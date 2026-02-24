# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification', type: :request do
  before do
    login_as_lexicon_editor
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
