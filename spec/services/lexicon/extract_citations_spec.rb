# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractCitations do
  subject(:result) { described_class.call(html_doc) }

  let(:html_doc) { File.open(filename) { |f| Nokogiri::HTML(f) } }

  context 'when male person is parsed', vcr: { cassette_name: 'lexicon/extract_citations_00024' } do
    let(:filename) { Rails.root.join('spec/fixtures/files/lexicon/00024.php') }

    it 'parses citations' do
      expect(result.size).to eq(4)
    end
  end

  context 'when female person is parsed', vcr: { cassette_name: 'lexicon/extract_citations_00002' } do
    let(:filename) { Rails.root.join('spec/fixtures/files/lexicon/00002.php') }

    it 'parses citations' do
      expect(result.size).to eq(53)
    end
  end

  context 'when a stray </span> inside a <li> prematurely closes the parent span' do
    # Regression test for 00034.php: a stray </span> after </b> inside a citation <li>
    # caused Nokogiri to prematurely close the <span dir="rtl"> wrapping the citations section.
    # This displaced all remaining content (title text, subsequent citation groups) as siblings
    # of the closed <span>, causing ExtractCitations to miss them entirely and the LLM to
    # receive a truncated <li> with no title, triggering a validation failure.
    let(:filename) { Rails.root.join('spec/fixtures/files/lexicon/stray_span_closing.php') }

    it 'includes displaced citation content from span siblings in the HTML sent to ParseCitations' do
      captured_html = nil
      allow(Lexicon::ParseCitations).to receive(:call) do |html|
        captured_html = html
        []
      end

      result

      expect(captured_html).to include('כותרת שעברה לחוץ')
    end
  end
end
