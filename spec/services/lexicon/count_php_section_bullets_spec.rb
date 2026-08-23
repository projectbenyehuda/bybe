# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::CountPhpSectionBullets do
  subject(:counts) { described_class.call(content) }

  context 'when content is blank' do
    let(:content) { '' }

    it 'reports no section at all' do
      expect(counts).to eq(works: nil, citations: nil, links: nil)
    end
  end

  context 'when all three sections are present' do
    let(:content) { Rails.root.join('spec/fixtures/files/lexicon/ul_directly_after_citations_header.php').read }

    it 'counts the list items of each section separately' do
      expect(counts).to eq(works: 1, citations: 3, links: 1)
    end
  end

  context 'when a section is present but holds no list items' do
    let(:content) { Rails.root.join('spec/fixtures/files/lexicon/j9u_only.php').read }

    it 'reports zero rather than nil, telling an empty section apart from a missing one' do
      expect(counts).to include(works: 0, citations: 0)
    end
  end

  context 'when the bibliography section is missing entirely' do
    let(:content) { '<p><font><a name="Books">ספריו:</a></font></p><ul><li>ספר</li></ul>' }

    it 'reports nil for that section' do
      expect(counts).to eq(works: 1, citations: nil, links: nil)
    end
  end

  it 'ignores whitespace-only list items, as migration itself does' do
    content = '<a name="Bib.">x</a><ul><li>ציטוט</li><li>&nbsp;</li><li>   </li></ul>'
    expect(described_class.call(content)[:citations]).to eq(1)
  end
end
