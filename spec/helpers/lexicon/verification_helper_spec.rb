# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::VerificationHelper, type: :helper do
  describe '#text_dir' do
    it 'returns nil for blank text' do
      expect(helper.text_dir('')).to be_nil
      expect(helper.text_dir(nil)).to be_nil
    end

    it 'returns ltr for purely Latin text' do
      expect(helper.text_dir('Shakespeare Hamlet')).to eq('ltr')
    end

    it 'returns ltr when fewer than 20% Hebrew characters' do
      # 1 Hebrew char out of 10 total = 10% < 20%
      expect(helper.text_dir("Hello Worldא")).to eq('ltr')
    end

    it 'returns nil for mostly Hebrew text' do
      expect(helper.text_dir('שקספיר המלט')).to be_nil
    end

    it 'returns nil when exactly 20% Hebrew characters' do
      # "Hello   אב" = 10 chars (5 letters + 3 spaces + 2 Hebrew) = exactly 20%
      # The threshold is < 0.2, so exactly 20% returns nil
      expect(helper.text_dir("Hello   אב")).to be_nil
    end

    it 'returns ltr for mixed text where Hebrew is below threshold' do
      # A title like "The Bible - תנ״ך" with mostly Latin
      expect(helper.text_dir("The Tanakh א")).to eq('ltr')
    end
  end

  describe '#work_card_css' do
    let(:work) { build_stubbed(:lex_person_work) }

    context 'when work is verified in checklist' do
      let(:checklist) do
        { 'works' => { 'items' => { work.id.to_s => { 'verified' => true } } } }
      end

      it 'returns verified' do
        expect(helper.work_card_css(work, checklist)).to eq('verified')
      end
    end

    context 'when work is not verified in checklist' do
      let(:checklist) do
        { 'works' => { 'items' => { work.id.to_s => { 'verified' => false } } } }
      end

      it 'returns not-verified' do
        expect(helper.work_card_css(work, checklist)).to eq('not-verified')
      end
    end

    context 'when work has no checklist entry' do
      let(:checklist) { { 'works' => { 'items' => {} } } }

      it 'returns not-verified' do
        expect(helper.work_card_css(work, checklist)).to eq('not-verified')
      end
    end

    context 'when works key is missing from checklist' do
      let(:checklist) { {} }

      it 'returns not-verified' do
        expect(helper.work_card_css(work, checklist)).to eq('not-verified')
      end
    end
  end
end
