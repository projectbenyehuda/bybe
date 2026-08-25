# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ManifestationHelper do
  describe '#options_from_images' do
    let(:image_data) { Rails.root.join('spec/fixtures/files/test_image.jpg').binread }

    # Pin the dimensions so data-width/data-height are deterministic. 'analyzed' must live in the
    # metadata JSON, otherwise the helper calls blob.analyze and overwrites them with the real size.
    def stamp_dimensions(attachment, width, height)
      blob = attachment.blob
      blob.update!(metadata: blob.metadata.merge('analyzed' => true, 'width' => width, 'height' => height))
    end

    context 'with a LexEntry' do
      let(:entry) { create(:lex_entry, :person) }

      before do
        entry.attachments.attach(io: StringIO.new(image_data), filename: 'image004.jpg',
                                 content_type: 'image/jpeg')
        stamp_dimensions(entry.attachments.first, 200, 299)
      end

      it 'offers each attached image, valued by its user-friendly download path' do
        options = Nokogiri::HTML.fragment(helper.options_from_images(entry.reload)).css('option')

        expect(options.map(&:text)).to eq ['image004.jpg']
        expect(options.first['value']).to eq "/files/lex/#{entry.id}/image004.jpg"
        expect(options.first['data-width']).to eq '200'
        expect(options.first['data-height']).to eq '299'
      end

      it 'skips non-image attachments' do
        entry.attachments.attach(io: StringIO.new('not an image'), filename: 'source.pdf',
                                 content_type: 'application/pdf')

        options = Nokogiri::HTML.fragment(helper.options_from_images(entry.reload)).css('option')

        expect(options.map(&:text)).to eq ['image004.jpg']
      end
    end

    context 'with a Manifestation' do
      let(:manifestation) { create(:manifestation, status: :published) }

      before do
        manifestation.images.attach(io: StringIO.new(image_data), filename: 'plate.jpg',
                                    content_type: 'image/jpeg')
        stamp_dimensions(manifestation.images.first, 800, 600)
      end

      it 'still reads images off the images association' do
        options = Nokogiri::HTML.fragment(helper.options_from_images(manifestation.reload)).css('option')

        expect(options.map(&:text)).to eq ['plate.jpg']
        expect(options.first['value']).to eq "/files/text/#{manifestation.id}/plate.jpg"
        expect(options.first['data-width']).to eq '800'
      end
    end
  end
end
