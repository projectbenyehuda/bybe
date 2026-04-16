# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MakeFreshDownloadable do
  subject(:service) { described_class.new }

  let(:work) { create(:work) }
  let(:expression) { create(:expression, work: work) }
  let(:manifestation) { create(:manifestation, expression: expression, title: 'Test') }

  describe '#images_to_absolute_url (private)' do
    # Expose private method for testing
    def images_to_absolute_url(html)
      service.send(:images_to_absolute_url, html)
    end

    context 'when HTML contains /files/:record_type/:record_id/:filename URLs (HTML-inserted images)' do
      let(:html) do
        "<p>Text</p><img src=\"/files/text/#{manifestation.id}/photo.jpg\" " \
          'alt="photo.jpg" style="width:800px;height:600px;object-fit:contain">'
      end

      it 'embeds the image as a base64 data URL' do
        blob = instance_double(ActiveStorage::Blob, content_type: 'image/jpeg')
        allow(blob).to receive(:download).and_return('fake_jpeg_data')
        allow(manifestation).to receive(:blob_by_filename).with('photo.jpg').and_return(blob)
        allow(Manifestation).to receive(:find_by).with(id: manifestation.id.to_s).and_return(manifestation)

        result = images_to_absolute_url(html)

        expect(result).to include('data:image/jpeg;base64,')
        expect(result).not_to include('/files/text/')
      end

      it 'leaves the URL unchanged when the record is not found' do
        allow(Manifestation).to receive(:find_by).with(id: manifestation.id.to_s).and_return(nil)
        allow(Rails.logger).to receive(:warn)

        result = images_to_absolute_url(html)

        expect(result).to include("/files/text/#{manifestation.id}/photo.jpg")
      end

      it 'leaves the URL unchanged when the blob is not found' do
        allow(Manifestation).to receive(:find_by).with(id: manifestation.id.to_s).and_return(manifestation)
        allow(manifestation).to receive(:blob_by_filename).with('photo.jpg').and_return(nil)

        result = images_to_absolute_url(html)

        expect(result).to include("/files/text/#{manifestation.id}/photo.jpg")
      end
    end

    context 'when HTML has no image tags' do
      it 'returns the HTML unchanged' do
        html = '<p>Just text</p>'
        expect(images_to_absolute_url(html)).to eq(html)
      end
    end
  end
end
