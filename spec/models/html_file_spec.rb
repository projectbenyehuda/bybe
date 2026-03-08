# frozen_string_literal: true

require 'rails_helper'

describe HtmlFile do
  describe '.pdf_from_any_html' do
    def minimal_html(body_content, extra_head = '')
      <<~HTML
        <html>
          <head>
            <meta charset="utf-8">
            <title>Test</title>
            #{extra_head}
            <style>@page {size: A4; margin: 1cm;} html, body {width: 19cm !important;} img {max-width: 100%;}</style>
          </head>
          <body dir="rtl">#{body_content}</body>
        </html>
      HTML
    end

    it 'returns a path to a non-empty PDF file for plain text HTML' do
      html = minimal_html('<p>שלום עולם</p><p>Hello world</p>')
      pdfpath = described_class.pdf_from_any_html(html)

      expect(pdfpath).to end_with('.pdf')
      expect(File.exist?(pdfpath)).to be true
      expect(File.size(pdfpath)).to be > 0
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'produces a valid PDF (starts with PDF magic bytes)' do
      html = minimal_html('<p>Test content</p>')
      pdfpath = described_class.pdf_from_any_html(html)

      expect(File.binread(pdfpath, 4)).to eq('%PDF')
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'handles HTML with an absolute-URL image' do
      # Simulate what MakeFreshDownloadable does: convert /rails/active_storage paths to absolute URLs
      img_tag = '<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png">'
      html = minimal_html("<p>Text with image</p><div style=\"width:190mm\">#{img_tag}</div>")
      pdfpath = described_class.pdf_from_any_html(html)

      expect(File.exist?(pdfpath)).to be true
      expect(File.size(pdfpath)).to be > 0
      expect(File.binread(pdfpath, 4)).to eq('%PDF')
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'handles HTML without images' do
      html = minimal_html('<p>Plain text only, no images.</p>')
      pdfpath = described_class.pdf_from_any_html(html)

      expect(File.exist?(pdfpath)).to be true
      expect(File.size(pdfpath)).to be > 0
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end
  end

  describe '.create_WEM_new' do
    subject(:call) { html_file.create_WEM_new(author.id, title, markdown, true) }

    let(:html_file) { create(:html_file, status: status) }
    let(:author) { html_file.author }
    let(:translator) { html_file.translator }
    let(:markdown) { 'TEST' }
    let(:title) { '   TITLE WITH WHITESPACES ' }

    context 'when file is not accepted' do
      let(:status) { 'Unknown' }

      it { is_expected.to eq I18n.t(:must_accept_before_publishing) }
    end

    context 'when file is accepted' do
      let(:status) { 'Accepted' }

      let(:manifestation) { Manifestation.order(id: :desc).first }

      it 'creates WEM structure' do
        expect { call }.to change(Manifestation, :count).by(1)
                                                        .and change(Expression, :count).by(1)
                                                        .and change(Work, :count).by(1)
                                                        .and change(InvolvedAuthority, :count).by(2)
        expect(manifestation.authors).to eq [author]
        expect(manifestation.translators).to eq [translator]
        expect(manifestation).to have_attributes(
          title: 'TITLE WITH WHITESPACES', # whitespaces stripped
          authors: [author],
          translators: [translator]
        )
      end
    end
  end
end
