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

  context 'when the document is well-formed and each subject is a separate closed <font> header' do
    # Regression test for 00006.php: the updated (well-formed) export no longer relies on an
    # unclosed <font> wrapper to nest the whole bibliography. Instead each subject is its own
    # properly-closed <font color="#FF0000"> header sitting as a flat sibling beside its <ul>.
    # The old sibling-walk only continued across font[size=2], so it stopped at the second subject
    # header and only the first citation group was migrated.
    let(:filename) { Rails.root.join('spec/fixtures/files/lexicon/00006.php') }

    it 'collects every citation group, not just the first one' do
      captured_html = nil
      allow(Lexicon::ParseCitations).to receive(:call) do |html|
        captured_html = html
        []
      end

      result

      expect(captured_html).not_to be_nil
      # All 16 citations across the subject groups must reach ParseCitations.
      expect(Nokogiri::HTML(captured_html).css('li').size).to eq(16)
      # Content from a late subject group (the last one) must be present, proving the walk did not
      # stop at the first subject header.
      expect(captured_html).to include('בית חמשת החושים')
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
