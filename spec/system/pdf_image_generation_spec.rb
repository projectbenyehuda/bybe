# frozen_string_literal: true

require 'rails_helper'

# System-level test for PDF image generation.
# Verifies that images referenced in a Manifestation's markdown are:
#   1. embedded in the generated PDF (not missing), and
#   2. constrained to the page width via CSS (not cut off).
#
# How image access works in tests:
#   wkhtmltopdf 0.12.6 defaults to --disable-local-file-access, which blocks
#   reading local disk files referenced from the HTML. ActiveStorage HTTP
#   redirect URLs are also inaccessible without a running server. We therefore
#   stub pdf_from_any_html to add --enable-local-file-access and reference the
#   image via a file:// URL pointing to its ActiveStorage disk location. This
#   lets wkhtmltopdf embed the image without a server while still exercising
#   the full GetFreshManifestationDownloadable → MakeFreshDownloadable pipeline.
RSpec.describe 'PDF image generation', type: :system do
  let(:test_image_path) { '/home/asaf/Downloads/test.jpg' }
  let(:manifestation) { create(:manifestation) }
  let(:captured_html) { [] }

  # wkhtmltopdf with local file access enabled — mirrors what happens in
  # production (where images are served via HTTP), but works without a server.
  def pdf_from_html_with_local_file_access(html_buffer)
    tmpfile = Tempfile.new(['pdf2html__', '.html'])
    tmpfile.write(html_buffer)
    tmpfile.flush
    tmpfilename = tmpfile.path
    `wkhtmltopdf --encoding 'UTF-8' --enable-local-file-access --page-width 20cm page #{tmpfilename} #{tmpfilename}.pdf`
    tmpfile.close
    "#{tmpfilename}.pdf"
  end

  before do
    skip 'test image not found at /home/asaf/Downloads/test.jpg' unless File.exist?(test_image_path)

    allow(HtmlFile).to receive(:pdf_from_any_html) do |html|
      captured_html << html
      pdf_from_html_with_local_file_access(html)
    end

    manifestation.images.attach(
      io: File.open(test_image_path),
      filename: 'test.jpg',
      content_type: 'image/jpeg'
    )

    # Resolve the actual disk path of the stored blob so wkhtmltopdf can read
    # it via a file:// URL (avoids needing a running HTTP server in tests).
    image_disk_path = ActiveStorage::Blob.service.path_for(manifestation.images.first.blob.key)

    manifestation.update!(
      markdown: "# תמונת בדיקה\n\n![test image](file://#{image_disk_path})\n\nטקסט לאחר התמונה."
    )
  end

  it 'generates HTML with a <head> tag so CSS can be injected' do
    GetFreshManifestationDownloadable.call(manifestation, 'pdf')
    msg = 'GetFreshManifestationDownloadable must produce a full HTML document with a <head> tag ' \
          'so that MakeFreshDownloadable can inject the image-scaling CSS into it.'
    expect(captured_html.first).to include('</head>'), msg
  end

  it 'injects the image-scaling CSS into the <head>' do
    GetFreshManifestationDownloadable.call(manifestation, 'pdf')
    html = captured_html.first
    msg = 'Expected the image-scaling CSS to be present inside <head>. ' \
          'Without it, oversized images will overflow the page and be cut off.'
    expect(html).to include('img {max-width: 100% !important;'), msg
    expect(html).to include('height: auto !important;')
  end

  it 'generates a PDF that embeds the image' do
    dl = GetFreshManifestationDownloadable.call(manifestation, 'pdf')
    pdf_bytes = dl.stored_file.download.b

    # The test.jpg is 2.4 MB. Even at aggressive compression, an embedded JPEG
    # adds at minimum tens of KB to the PDF. A plain-text PDF for a short
    # manifest is ~25 KB. We require at least 100 KB total to confirm embedding.
    msg = "PDF was only #{pdf_bytes.length} bytes — image does not appear to be embedded. " \
          'Expected at least 100 KB when the 2.4 MB test image is included.'
    expect(pdf_bytes.length).to be > 100_000, msg
  end

  it 'generates a PDF substantially larger than one without an image' do
    plain = create(:manifestation, markdown: "# כותרת\n\nרק טקסט, ללא תמונה.")
    plain_size = GetFreshManifestationDownloadable.call(plain, 'pdf').stored_file.download.length

    image_size = GetFreshManifestationDownloadable.call(manifestation, 'pdf').stored_file.download.length

    msg = "Image PDF (#{image_size} B) should be at least 50 KB larger than " \
          "plain text PDF (#{plain_size} B). Difference was only #{image_size - plain_size} B, " \
          'indicating the image was not embedded.'
    expect(image_size).to be > plain_size + 50_000, msg
  end
end
