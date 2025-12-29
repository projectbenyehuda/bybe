# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LexEntry, type: :model do
  describe '#profile_image' do
    let(:entry) { create(:lex_entry) }

    context 'when no profile_image_id is set' do
      it 'returns nil' do
        expect(entry.profile_image).to be_nil
      end
    end

    context 'when profile_image_id is set' do
      it 'returns the attachment with that ID' do
        # Attach a file to the entry
        entry.attachments.attach(
          io: StringIO.new('test image content'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )

        attachment = entry.attachments.first
        entry.update!(profile_image_id: attachment.id)

        expect(entry.profile_image).to eq(attachment)
      end
    end
  end
end
