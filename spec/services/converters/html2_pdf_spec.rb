# frozen_string_literal: true

require 'rails_helper'

describe Converters::Html2Pdf do
  let(:tmp_dir) { Rails.root.join('tmp').to_s }
  let(:output_path) do
    tmpfile = Tempfile.new(['html2pdf_spec__', '.pdf'], tmp_dir)
    tmpfile.path.tap { tmpfile.close! }
  end

  after { FileUtils.rm_f(output_path) }

  describe '#call' do
    subject(:result) { described_class.call(html, output_path) }

    context 'with plain text HTML' do
      let(:html) { '<p>שלום עולם</p><p>Hello world</p>' }

      it 'returns true' do
        expect(result).to be true
      end

      it 'writes a non-empty PDF to the output path' do
        result
        expect(File.exist?(output_path)).to be true
        expect(File.size(output_path)).to be > 0
      end

      it 'produces a valid PDF (starts with PDF magic bytes)' do
        result
        expect(File.binread(output_path, 4)).to eq('%PDF')
      end
    end

    context 'with a full HTML document (has </head>)' do
      let(:html) { '<html><head><title>Test</title></head><body><p>content</p></body></html>' }

      it 'returns true and creates a PDF' do
        expect(result).to be true
        expect(File.exist?(output_path)).to be true
      end
    end

    context 'with HTML containing an active_storage image' do
      # A 1x1 transparent PNG as a data: URI — no network required
      let(:tiny_png) do
        'data:image/png;base64,' \
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg=='
      end
      let(:html) { '<p>Text</p><img src="/rails/active_storage/blobs/xxx/img.jpg">' }

      it 'returns true and creates a PDF' do
        expect(result).to be true
        expect(File.exist?(output_path)).to be true
      end
    end
  end

  describe 'prepare_html (via call)' do
    let(:service) { described_class.new }

    context 'when HTML is a bare fragment (no </head>)' do
      let(:html) { '<div>content</div>' }

      it 'wraps the fragment in a full document with RTL body and PDF CSS' do
        service.call(html, output_path)
        # The PDF is produced, meaning the HTML was valid enough for Chromium — the
        # structural test is exercised via prepare_html's unit-level effect below.
        expect(File.exist?(output_path)).to be true
      end
    end

    it 'injects PDF CSS into an existing </head> tag without adding a full wrapper' do
      # Access the private method directly to test prepare_html in isolation
      result = service.send(:prepare_html, '<html><head><title>T</title></head><body>x</body></html>')

      expect(result).to include(Converters::Html2Pdf::PDF_CSS)
      expect(result).not_to include('<!DOCTYPE html><html><head>')
    end

    it 'wraps active_storage images in a max-width div' do
      result = service.send(:prepare_html, '<img src="/rails/active_storage/blobs/xxx/img.jpg">')

      expect(result).to include('<div style="max-width:100%"><img src="/rails/active_storage')
    end

    it 'wraps a bare fragment in a full document with RTL body and PDF CSS' do
      result = service.send(:prepare_html, '<div>content</div>')

      expect(result).to include('<!DOCTYPE html>')
      expect(result).to include(Converters::Html2Pdf::PDF_CSS)
      expect(result).to include("<body dir='rtl'>")
      expect(result).to include('<div>content</div>')
    end
  end
end
