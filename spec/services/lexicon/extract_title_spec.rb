# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractTitle do
  subject(:call) { described_class.call(file) }

  context 'when person file is provided' do
    let(:file) { Rails.root.join('spec/fixtures/files/lexicon/00024.php') }

    it { is_expected.to eq('שמואל בס') }

    context 'when title is written in several spans' do
      let(:file) { Rails.root.join('spec/fixtures/files/lexicon/tsifroni.php') }

      it { is_expected.to eq('גבריאל צפרוני') }
    end
  end

  context 'when file declares no charset' do
    let(:file) { Rails.root.join('spec/fixtures/files/lexicon/no_charset_declaration.php') }

    # Regression: libxml2 falls back to ISO-8859-1 for documents that declare no charset,
    # which used to store byte-per-character mojibake in lex_entries.title.
    it { is_expected.to eq('נורית זרחי') }
  end

  context 'when publication file is provided' do
    let(:file) { Rails.root.join('spec/fixtures/files/lexicon/02645001.php') }

    it { is_expected.to eq('אליעזר ירושלמי') }
  end
end
