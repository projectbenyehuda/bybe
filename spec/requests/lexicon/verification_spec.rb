# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lexicon::Verification', type: :request do
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
end
