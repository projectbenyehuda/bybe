# frozen_string_literal: true

require 'rails_helper'

describe HtmlFile do
  describe '.pdf_from_any_html' do
    # A 1x1 transparent PNG encoded as data: URI — no network required
    let(:tiny_png_data_uri) do
      'data:image/png;base64,' \
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=='
    end

    def pdf_html(body_content)
      "<div dir='rtl'>#{body_content}</div>"
    end

    it 'returns a path to a non-empty PDF file for plain text HTML' do
      pdfpath = described_class.pdf_from_any_html(pdf_html('<p>שלום עולם</p><p>Hello world</p>'))

      expect(pdfpath).to end_with('.pdf')
      expect(File.exist?(pdfpath)).to be true
      expect(File.size(pdfpath)).to be > 0
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'produces a valid PDF (starts with PDF magic bytes)' do
      pdfpath = described_class.pdf_from_any_html(pdf_html('<p>Test content</p>'))

      expect(File.binread(pdfpath, 4)).to eq('%PDF')
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'handles HTML with an embedded image (no network required)' do
      img_tag = "<img src=\"#{tiny_png_data_uri}\">"
      pdfpath = described_class.pdf_from_any_html(pdf_html("<p>Text with image</p>#{img_tag}"))

      expect(File.exist?(pdfpath)).to be true
      expect(File.size(pdfpath)).to be > 0
      expect(File.binread(pdfpath, 4)).to eq('%PDF')
    ensure
      File.delete(pdfpath) if pdfpath && File.exist?(pdfpath)
    end

    it 'handles HTML without images' do
      pdfpath = described_class.pdf_from_any_html(pdf_html('<p>Plain text only, no images.</p>'))

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
