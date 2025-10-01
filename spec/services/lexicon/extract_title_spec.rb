# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractTitle do
  subject(:call) { described_class.call(file) }

  context 'when person file is provided' do
    let(:file) { Rails.root.join('spec/data/lexicon/00024.php') }

    it { is_expected.to eq('שמואל בס (1899־1949)') }

    context 'when title is written in several spans' do
      let(:file) { Rails.root.join('spec/data/lexicon/tsifroni.php') }

      it { is_expected.to eq('גבריאל צפרוני (1915־2011)') }
    end
  end

  context 'when publication file is provided' do
    let(:file) { Rails.root.join('spec/data/lexicon/02645001.php') }

    it { is_expected.to eq('אליעזר ירושלמי (1900–1962)') }
  end
end
