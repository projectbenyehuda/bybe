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

        patch url, params: { attachment_id: attachment.id }, as: :json

        expect(response).to have_http_status(:success)
        expect(entry.reload.profile_image_id).to eq(attachment.id)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['profile_image_id']).to eq(attachment.id)
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

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Attachment not found')
      end
    end

    context 'when attachment_id is invalid' do
      it 'returns not found error' do
        patch url, params: { attachment_id: 99999 }, as: :json

        expect(response).to have_http_status(:not_found)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end
  end
end
