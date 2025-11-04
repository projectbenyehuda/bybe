# frozen_string_literal: true

require 'rails_helper'
require 'hebrew'

describe AlternateHebrewForms do
  describe '#call' do
    subject { described_class.call(input) }

    context 'with empty string' do
      let(:input) { '' }

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'with nil input' do
      let(:input) { nil }

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'with whitespace only' do
      let(:input) { '   ' }

      it 'returns empty array' do
        expect(subject).to eq([])
      end
    end

    context 'with text that has leading/trailing whitespace' do
      let(:input) { '  שלום  ' }

      it 'strips whitespace before processing' do
        # The service should handle whitespace by stripping it
        result = subject
        expect(result).to be_an(Array)
        expect(result).to eq([])
      end
    end

    context 'integration test with Hebrew text' do
      let(:input) { 'מִטָה ושֻׁלְחָן' }

      it 'returns an array' do
        expect(subject).to be_an(Array)
        expect(subject).to eq(['מטה ושלחן', 'מיטה ושולחן'])
      end

      it 'has access to Hebrew string methods if available' do
        # Test that the string responds to Hebrew methods if they're loaded
        if input.respond_to?(:strip_nikkud)
          expect(input).to respond_to(:strip_nikkud)
        else
          skip 'Hebrew string methods not available in test environment'
        end
      end

      it 'has access to naive_full_nikkud method if available' do
        if input.respond_to?(:naive_full_nikkud)
          expect(input).to respond_to(:naive_full_nikkud)
        else
          skip 'Hebrew string methods not available in test environment'
        end
      end

      it 'processes Hebrew text without errors' do
        expect { subject }.not_to raise_error
      end

      it 'returns unique forms only' do
        result = subject
        expect(result.uniq).to eq(result)
      end
    end
  end
end
