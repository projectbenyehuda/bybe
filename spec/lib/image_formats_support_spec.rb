# frozen_string_literal: true

require 'rails_helper'

# This spec ensures image_processing can read the image formats we use in our application.
# Some formats (e.g. BMP) are read through ImageMagick rather than libvips itself, so support
# depends on the system libraries.
# rubocop:disable RSpec/DescribeClass
describe 'Image formats support' do
  shared_examples 'process image successfully' do |image_format|
    context "when processing an image in #{image_format} format" do
      it 'processes the image without errors' do
        source = Rails.root.join("spec/fixtures/files/test_image.#{image_format}").to_s
        expect do
          # Variants are written in a web format, as ActiveStorage does.
          ImageProcessing::Vips.source(source).resize_to_limit(10, 10).convert('png').call
        end.not_to raise_error
      end
    end
  end

  it_behaves_like 'process image successfully', 'jpg'
  it_behaves_like 'process image successfully', 'png'
  it_behaves_like 'process image successfully', 'tiff'
  it_behaves_like 'process image successfully', 'bmp'
end
# rubocop:enable RSpec/DescribeClass
