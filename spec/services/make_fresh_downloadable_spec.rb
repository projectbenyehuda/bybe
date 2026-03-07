# frozen_string_literal: true

require 'rails_helper'

describe MakeFreshDownloadable do
  let(:manifestation) { create(:manifestation) }

  describe '#call for pdf format' do
    let(:pdf_tempfile) { Tempfile.new(['test', '.pdf']) }
    let(:captured_html) { [] }

    before do
      pdf_tempfile.write('fake pdf content')
      pdf_tempfile.flush
      allow(HtmlFile).to receive(:pdf_from_any_html) do |html|
        captured_html << html
        pdf_tempfile.path
      end
    end

    after do
      pdf_tempfile.close
      pdf_tempfile.unlink
    end

    context 'when HTML contains images with explicit width and height attributes' do
      let(:html_with_sized_images) do
        <<~HTML
          <html><head></head><body>
            <img src="/rails/active_storage/blobs/123/photo.jpg" width="1200" height="800">
            <img src="/some/other/image.png" width="500" height="300">
          </body></html>
        HTML
      end

      it 'strips width attributes from img tags' do
        described_class.call('pdf', 'test.pdf', html_with_sized_images, manifestation, 'Author')
        expect(captured_html.first).not_to include('width="1200"')
        expect(captured_html.first).not_to include('width="500"')
      end

      it 'strips height attributes from img tags' do
        described_class.call('pdf', 'test.pdf', html_with_sized_images, manifestation, 'Author')
        expect(captured_html.first).not_to include('height="800"')
        expect(captured_html.first).not_to include('height="300"')
      end

      it 'preserves the src attribute' do
        described_class.call('pdf', 'test.pdf', html_with_sized_images, manifestation, 'Author')
        expect(captured_html.first).to include('/some/other/image.png')
      end
    end

    context 'when HTML is a bare fragment with no <head> tag (Manifestation path)' do
      let(:bare_html) { '<div dir="rtl"><p>text</p></div>' }

      it 'prepends the style tag so CSS still applies' do
        described_class.call('pdf', 'test.pdf', bare_html, manifestation, 'Author')
        expect(captured_html.first).to start_with('<style>')
        expect(captured_html.first).to include('img {max-width: 100% !important;')
      end
    end

    context 'when injecting CSS into the head' do
      let(:basic_html) { '<html><head></head><body><p>text</p></body></html>' }

      it 'includes max-width with !important on img rule' do
        described_class.call('pdf', 'test.pdf', basic_html, manifestation, 'Author')
        expect(captured_html.first).to include('img {max-width: 100% !important;')
      end

      it 'includes height: auto with !important on img rule to preserve aspect ratio' do
        described_class.call('pdf', 'test.pdf', basic_html, manifestation, 'Author')
        expect(captured_html.first).to include('height: auto !important;')
      end

      it 'sets a white background to prevent gray wkhtmltopdf canvas' do
        described_class.call('pdf', 'test.pdf', basic_html, manifestation, 'Author')
        expect(captured_html.first).to include('background-color: white')
      end

      it 'resets body margin and padding to match implicit-body behaviour from bare-div rendering' do
        described_class.call('pdf', 'test.pdf', basic_html, manifestation, 'Author')
        expect(captured_html.first).to include('margin: 0')
        expect(captured_html.first).to include('padding: 0')
      end

      it 'does not set an explicit body width that would conflict with page margins' do
        described_class.call('pdf', 'test.pdf', basic_html, manifestation, 'Author')
        expect(captured_html.first).not_to include('width: 20cm')
      end
    end

    context 'when HTML contains active_storage images' do
      context 'with an unresolvable blob id (fallback path)' do
        let(:html_with_as_image) do
          '<html><head></head><body><img src="/rails/active_storage/blobs/redirect/invalid-id/photo.jpg"></body></html>'
        end

        it 'wraps unresolvable active_storage images in a constraining div' do
          # find_signed! raises for an invalid id, so the URL is left unchanged and the div-wrap applies
          described_class.call('pdf', 'test.pdf', html_with_as_image, manifestation, 'Author')
          expect(captured_html.first).to include('<div style="width:209mm">')
        end
      end

      context 'with a real attached blob' do
        let(:image_content) { "GIF89a\x01\x00\x01\x00\x00\xFF\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x00;" }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new(image_content),
            filename: 'test.gif',
            content_type: 'image/gif'
          )
        end
        let(:html_with_real_blob) do
          signed_id = blob.signed_id
          '<html><head></head><body>' \
            "<img src=\"/rails/active_storage/blobs/redirect/#{signed_id}/test.gif\">" \
            '</body></html>'
        end

        after { blob.purge }

        it 'embeds the image as a base64 data: URL' do
          described_class.call('pdf', 'test.pdf', html_with_real_blob, manifestation, 'Author')
          expect(captured_html.first).to include('src="data:image/gif;base64,')
        end

        it 'does not leave any active_storage HTTP reference in the HTML' do
          described_class.call('pdf', 'test.pdf', html_with_real_blob, manifestation, 'Author')
          expect(captured_html.first).not_to include('/rails/active_storage')
        end
      end
    end
  end
end
