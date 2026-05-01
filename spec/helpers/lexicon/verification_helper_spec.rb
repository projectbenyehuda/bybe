# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lexicon::VerificationHelper, type: :helper do
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
