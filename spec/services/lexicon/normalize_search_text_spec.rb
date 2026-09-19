# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::NormalizeSearchText do
  subject(:normalized) { described_class.call(text) }

  describe 'Hebrew points and cantillation' do
    context 'with niqqud inside a word' do
      let(:text) { 'אמונה אֵלון' }

      it { is_expected.to eq 'אמונה אלון' }
    end

    context 'with the marks the hebrew gem\'s strip_nikkud leaves behind' do
      # meteg (U+05BD), rafe (U+05BF), qamats qatan (U+05C7) and the cantillation range all
      # fall outside String#strip_nikkud, which is why this service defines its own range.
      let(:text) { 'מְשֶׁהׇֽֿ֑' }

      it { is_expected.to eq 'משה' }
    end
  end

  describe 'separators' do
    context 'with a maqaf' do
      let(:text) { 'בן־ציון בן־משה' }

      it 'becomes a space, so the name reads as the same words either way' do
        expect(normalized).to eq 'בן ציון בן משה'
      end
    end

    context 'with an ASCII hyphen' do
      let(:text) { 'משה בן-שאול' }

      it { is_expected.to eq 'משה בן שאול' }
    end

    context 'with an en dash between life years' do
      let(:text) { 'בן־ציון בן־משה (1943–2024)' }

      it { is_expected.to eq 'בן ציון בן משה (1943 2024)' }
    end
  end

  describe 'elisions' do
    context 'with gershayim in an acronym' do
      let(:text) { 'יואב כ״ץ' }

      it 'is dropped rather than spaced, so that a search for כץ can reach it' do
        expect(normalized).to eq 'יואב כץ'
      end
    end

    context 'with a geresh marking a transliterated sound' do
      let(:text) { 'יניב איצקוביץ׳' }

      it { is_expected.to eq 'יניב איצקוביץ' }
    end

    context 'with gershayim quoting a nickname' do
      let(:text) { 'רועי ״צ׳יקי״ ארד (1976)' }

      it { is_expected.to eq 'רועי ציקי ארד (1976)' }
    end

    context 'with ASCII and curly quotes' do
      let(:text) { %(ר' בנימין "the" ‘second’) }

      it { is_expected.to eq 'ר בנימין the second' }
    end
  end

  describe 'whitespace and case' do
    context 'with runs of whitespace left by dropped punctuation' do
      let(:text) { '  שרה     לוי  ' }

      it { is_expected.to eq 'שרה לוי' }
    end

    context 'with a Latin-script title' do
      let(:text) { 'Gail HAREVEN' }

      it 'downcases, since lex_entries is a utf8mb4_bin (case-sensitive) table' do
        expect(normalized).to eq 'gail hareven'
      end
    end
  end

  context 'when the text is nil' do
    let(:text) { nil }

    it { is_expected.to be_nil }
  end

  describe '.elasticsearch_mappings' do
    subject(:mappings) { described_class.elasticsearch_mappings }

    it 'escapes separators to a replacement space' do
      expect(mappings).to include('\\u05BE=>\\u0020')
    end

    it 'gives elided characters an empty replacement' do
      expect(mappings).to include('\\u05F4=>')
    end

    it 'covers every character the Ruby normalizer rewrites' do
      expect(mappings.size).to eq described_class::MAPPINGS.size
    end
  end
end
