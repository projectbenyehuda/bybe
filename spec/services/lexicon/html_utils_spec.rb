# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::HtmlUtils do
  describe '.parse_file' do
    subject(:doc) { described_class.parse_file(file) }

    let(:fixtures_dir) { Rails.root.join('spec/fixtures/files/lexicon') }

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
end
