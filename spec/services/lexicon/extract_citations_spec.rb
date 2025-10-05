# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractCitations do
  subject(:result) { described_class.call(html_doc) }

  let(:html_doc) { File.open(filename) { |f| Nokogiri::HTML(f) } }

  context 'when male person is parsed' do
    let(:filename) { Rails.root.join('spec/data/lexicon/00024.php') }

    it 'parses citations' do
      expect(result.size).to eq(4)
    end
  end

  context 'when female person is parsed' do
    let(:filename) { Rails.root.join('spec/data/lexicon/00002.php') }

    it 'parses citations' do
      expect(result.size).to eq(53)
    end
  end
end
