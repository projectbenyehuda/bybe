# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::HtmlUtils do
  let(:fixtures_dir) { Rails.root.join('spec/fixtures/files/lexicon') }

  describe '.parse_file' do
    subject(:doc) { described_class.parse_file(file) }

    # The Hebrew entry title, as it appears in the first cell of the header table
    def title_text
      doc.at_css('table#table5 td p[align="center"]').text.squish
    end

    context 'when the file declares charset=UTF-8' do
      let(:file) { fixtures_dir.join('00024.php') }

      it 'reads Hebrew correctly' do
        expect(title_text).to start_with('שמואל בס')
      end
    end

    context 'when the file declares no charset at all' do
      let(:file) { fixtures_dir.join('no_charset_declaration.php') }

      it 'defaults to UTF-8 instead of libxml2 ISO-8859-1 fallback' do
        expect(title_text).to start_with('נורית זרחי')
      end
    end

    context 'when the file declares windows-1255 and really is windows-1255' do
      let(:file) { fixtures_dir.join('windows_1255_declared.php') }

      it 'honours the declared encoding rather than forcing UTF-8' do
        expect(title_text).to start_with('נורית זרחי')
      end
    end
  end

  describe '#works_header_element and #bio_elements' do
    subject(:helper) { Class.new { include Lexicon::HtmlUtils }.new }

    let(:doc) { described_class.parse_file(fixtures_dir.join(file)) }
    let(:heading_table) { doc.at_css('table[width="100%"]') }
    let(:works_header) { helper.works_header_element(doc) }
    let(:bio_text) { helper.bio_elements(heading_table).map(&:text).join(' ').squish }

    context 'when the works section is a sibling of the bio' do
      let(:file) { '00002.php' }

      it 'returns the <p> wrapping the anchor, which the works lists follow' do
        expect(works_header.name).to eq('p')
        expect(works_header.at_css('a[name="Books"]')).to be_present
      end

      it 'ends the bio before the works section' do
        expect(bio_text).to include('סופרת, משוררת ועורכת')
        expect(bio_text).not_to include('ספריה:')
      end
    end

    context 'when the works section is wrapped in a blockquote' do
      let(:file) { 'works_in_blockquote.php' }

      it 'finds the header inside the blockquote' do
        expect(works_header.name).to eq('p')
        expect(works_header.parent.name).to eq('blockquote')
      end

      it 'keeps the blockquote out of the bio' do
        expect(bio_text).to eq('ביוגרפיה קצרה של הסופרת לדוגמה. נולדה בשנת 1936 וכתבה ספרים רבים.')
      end
    end

    context 'when the heading table is wrapped in a paragraph the works section is outside of' do
      let(:file) { 'works_outside_heading_wrapper.php' }

      it 'climbs out of the wrapper to collect the bio' do
        expect(bio_text).to eq('ביוגרפיה קצרה של הסופר לדוגמה. נולד בשנת 1906 ונפטר בשנת 1966.')
      end

      it 'finds the header at the outer nesting level' do
        expect(works_header.text.squish).to eq('ספריו:')
      end
    end

    context 'when the header anchor has no <p>/<font> wrapper' do
      let(:file) { 'works_header_without_wrapper.php' }

      it 'falls back to the bare anchor, which the works list follows' do
        expect(works_header.name).to eq('a')
        expect(works_header['name']).to eq('Books')
      end

      it 'ends the bio at the bare anchor' do
        expect(bio_text).to eq('ביוגרפיה קצרה של הסופרת לדוגמה. נולדה בשנת 1963.')
      end
    end

    context 'when the entry has no works section' do
      let(:file) { 'no_links.php' }

      it 'returns no works header' do
        expect(works_header).to be_nil
      end
    end
  end

  describe '#works_section_end?' do
    subject(:helper) { Class.new { include Lexicon::HtmlUtils }.new }

    def element(html)
      Nokogiri::HTML::DocumentFragment.parse(html).first_element_child
    end

    it 'is true for a header opening another section' do
      expect(helper).to be_works_section_end(element('<font><a name="Bib.">על המחבר:</a></font>'))
    end

    it 'is false for a work-type sub-header repeating the works anchor' do
      expect(helper).not_to be_works_section_end(element('<font>תרגומיה<a name="Books">:</a></font>'))
    end

    it 'is false for an element that is not a header at all' do
      expect(helper).not_to be_works_section_end(element('<ul><li>ספר</li></ul>'))
    end
  end
end
