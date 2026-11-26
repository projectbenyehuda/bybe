# frozen_string_literal: true

# This spec is to ensure that image_processing gem supports the image formats we use in our application.
# Some formats require additional libraries to be installed in the system, so we want to make sure that the gem can 
# process them without errors.
describe 'Image formats support' do
  shared_examples 'process image successfully' do |image_format|
    context "when processing an image in #{image_format} format" do
      it 'processes the image without errors' do
        expect {
          ImageProcessing::Vips.source("spec/fixtures/files/test_image.#{image_format}").resize_to_limit(10, 10).call
        }.not_to raise_error
      end
    end
  end

  it_behaves_like 'process image successfully', 'jpg'
  it_behaves_like 'process image successfully', 'png'
  it_behaves_like 'process image successfully', 'tiff'
  it_behaves_like 'process image successfully', 'bmp'
end
