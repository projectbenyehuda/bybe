# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateKwicConcordance do
  describe '#call' do
    context 'with basic English text' do
      let(:labelled_texts) do
        [
          { label: 'Text A', buffer: 'The quick brown fox jumps over the lazy dog.' }
        ]
      end

      it 'generates concordance text with header' do
        result = described_class.call(labelled_texts)
        expect(result).to include('קונקורדנציה בתבנית KWIC')
        expect(result).to include('=' * 50)
      end

      it 'includes all unique tokens' do
        result = described_class.call(labelled_texts)
        expect(result).to include('מילה: The')
        expect(result).to include('מילה: quick')
        expect(result).to include('מילה: brown')
        expect(result).to include('מילה: fox')
      end

      it 'shows token in context with label and paragraph' do
        result = described_class.call(labelled_texts)
        expect(result).to include('[Text A, פסקה 1]')
        expect(result).to include('[fox]')
      end

      it 'shows before and after context' do
        result = described_class.call(labelled_texts)
        # Check that fox has proper context
        expect(result).to match(/quick brown.*\[fox\].*jumps over the/)
      end
    end

    context 'with multiple texts' do
      let(:labelled_texts) do
        [
          { label: 'Text A', buffer: 'The quick brown fox.' },
          { label: 'Text B', buffer: 'The brown bear.' }
        ]
      end

      it 'combines instances from multiple texts' do
        result = described_class.call(labelled_texts)
        # 'brown' should appear in both texts
        expect(result).to include('מילה: brown')
        expect(result).to include('[Text A, פסקה 1]')
        expect(result).to include('[Text B, פסקה 1]')
      end
    end

    context 'with Hebrew text and acronyms' do
      let(:labelled_texts) do
        [
          { label: 'טקסט א', buffer: 'מפא"י היתה מפלגה פוליטית ישראלית.' }
        ]
      end

      it 'preserves Hebrew acronyms' do
        result = described_class.call(labelled_texts)
        expect(result).to include('מילה: מפא"י')
      end

      it 'shows Hebrew context correctly' do
        result = described_class.call(labelled_texts)
        expect(result).to include('[טקסט א, פסקה 1]')
        expect(result).to match(/\[מפא"י\].*היתה מפלגה/)
      end
    end

    context 'with multiple paragraphs' do
      let(:labelled_texts) do
        [
          { label: 'Text', buffer: "First paragraph.\nSecond paragraph." }
        ]
      end

      it 'tracks paragraph numbers separately' do
        result = described_class.call(labelled_texts)
        expect(result).to include('[Text, פסקה 1]')
        expect(result).to include('[Text, פסקה 2]')
      end
    end

    context 'with empty text' do
      let(:labelled_texts) do
        [
          { label: 'Empty', buffer: '' }
        ]
      end

      it 'generates header even with no content' do
        result = described_class.call(labelled_texts)
        expect(result).to include('קונקורדנציה בתבנית KWIC')
      end

      it 'does not include any word entries' do
        result = described_class.call(labelled_texts)
        expect(result).not_to include('מילה:')
      end
    end
  end
end
