# frozen_string_literal: true

require 'rails_helper'

describe Toc do
  describe '#structure_okay?' do
    it 'accepts visual art between lexicon and translations' do
      toc = build(:toc, toc: "## מילונים ולקסיקונים\n\n## אמנות חזותית\n\n## יצירות מתורגמות\n")
      expect(toc.structure_okay?).to be true
    end

    it 'rejects visual art placed before lexicon' do
      toc = build(:toc, toc: "## אמנות חזותית\n\n## מילונים ולקסיקונים\n")
      expect(toc.structure_okay?).to be false
    end

    it 'rejects visual art placed after translations' do
      toc = build(:toc, toc: "## יצירות מתורגמות\n\n## אמנות חזותית\n")
      expect(toc.structure_okay?).to be false
    end
  end
end
