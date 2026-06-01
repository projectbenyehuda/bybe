# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::BioComparison do
  subject(:result) { described_class.call(item, source_content) }

  let(:item) { instance_double(LexPerson, bio: migrated_bio) }

  # Legacy file layout: heading table (title/years), then bio prose, then the
  # "Books" anchor that opens the works section. Only the prose between the
  # heading table and the Books anchor is the bio.
  let(:source_content) do
    <<~HTML
      <html><body>
        <table width="100%"><tr><td><p align="center"><font size="4">(1900-1970)</font></p></td></tr></table>
        <p>שלום עולם גדול, וטוב מאוד!</p>
        <p>שורה שנייה של הביוגרפיה כאן.</p>
        <p><font><a name="Books"></a>ספרים</font></p>
        <ul><li>ספר ראשון שלא נספר</li></ul>
      </body></html>
    HTML
  end

  context 'when the migrated bio matches the legacy bio' do
    let(:migrated_bio) { 'שלום עולם גדול וטוב מאוד שורה שנייה של הביוגרפיה כאן' }

    it 'tokenises the legacy bio, ignoring HTML tags and punctuation' do
      expect(result.legacy_words).to eq(%w(שלום עולם גדול וטוב מאוד שורה שנייה של הביוגרפיה כאן))
    end

    it 'tokenises the migrated bio' do
      expect(result.migrated_words).to eq(%w(שלום עולם גדול וטוב מאוד שורה שנייה של הביוגרפיה כאן))
    end

    it 'excludes the works section (after the Books anchor) from the legacy count' do
      expect(result.legacy_words).not_to include('ספרים', 'ספר', 'ראשון', 'נספר')
    end

    it 'does not exclude the heading-table years from being counted as bio' do
      # The years live inside the heading table, before the bio prose begins.
      expect(result.legacy_words).not_to include('1900', '1970')
    end

    it 'reports no discrepancy' do
      expect(result.difference).to eq(0)
      expect(result).not_to be_discrepancy
    end
  end

  context 'when exactly two words are missing from the migrated bio' do
    let(:migrated_bio) { 'שלום עולם גדול וטוב מאוד שורה שנייה של' }

    it 'stays within the two-word tolerance' do
      expect(result.difference).to eq(2)
      expect(result).not_to be_discrepancy
    end
  end

  context 'when more than two words are missing from the migrated bio' do
    let(:migrated_bio) { 'שלום עולם גדול וטוב מאוד שורה' }

    it 'reports a discrepancy' do
      expect(result.difference).to be > 2
      expect(result).to be_discrepancy
    end
  end

  context 'when the legacy source is blank' do
    let(:migrated_bio) { 'שלום עולם גדול' }
    let(:source_content) { nil }

    it 'treats the legacy bio as empty and reports a discrepancy' do
      expect(result.legacy_count).to eq(0)
      expect(result.migrated_count).to eq(3)
      expect(result).to be_discrepancy
    end
  end

  context 'when the migrated bio is blank' do
    let(:migrated_bio) { nil }

    it 'treats the migrated bio as empty' do
      expect(result.migrated_words).to eq([])
      expect(result.legacy_count).to eq(10)
      expect(result).to be_discrepancy
    end
  end
end
