# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParseKwicConcordance do
  describe '#call' do
    context 'with valid KWIC text' do
      let(:kwic_text) do
        <<~KWIC
          קונקורדנציה בתבנית KWIC
          ==================================================

          מילה: brown
          ----------------------------------------
          [First Work, פסקה 1] The quick [brown] fox jumps
          [Second Work, פסקה 1] The [brown] bear runs

          מילה: The
          ----------------------------------------
          [First Work, פסקה 1]  [The] quick brown fox
          [Second Work, פסקה 1]  [The] brown bear runs
        KWIC
      end

      it 'parses tokens correctly' do
        result = described_class.call(kwic_text)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:token]).to eq('brown')
        expect(result[1][:token]).to eq('The')
      end

      it 'parses instances correctly' do
        result = described_class.call(kwic_text)

        brown_entry = result[0]
        expect(brown_entry[:instances].length).to eq(2)

        first_instance = brown_entry[:instances][0]
        expect(first_instance[:label]).to eq('First Work')
        expect(first_instance[:paragraph]).to eq(1)
        expect(first_instance[:before_context]).to eq('The quick')
        expect(first_instance[:after_context]).to eq('fox jumps')

        second_instance = brown_entry[:instances][1]
        expect(second_instance[:label]).to eq('Second Work')
        expect(second_instance[:paragraph]).to eq(1)
        expect(second_instance[:before_context]).to eq('The')
        expect(second_instance[:after_context]).to eq('bear runs')
      end
    end

    context 'with Hebrew text' do
      let(:kwic_text) do
        <<~KWIC
          קונקורדנציה בתבנית KWIC
          ==================================================

          מילה: מפא"י
          ----------------------------------------
          [טקסט עברי, פסקה 1] היתה [מפא"י] מפלגה פוליטית
        KWIC
      end

      it 'handles Hebrew tokens correctly' do
        result = described_class.call(kwic_text)

        expect(result.length).to eq(1)
        expect(result[0][:token]).to eq('מפא"י')
        expect(result[0][:instances][0][:label]).to eq('טקסט עברי')
        expect(result[0][:instances][0][:before_context]).to eq('היתה')
        expect(result[0][:instances][0][:after_context]).to eq('מפלגה פוליטית')
      end
    end

    context 'with empty or nil text' do
      it 'returns empty array for nil' do
        result = described_class.call(nil)
        expect(result).to eq([])
      end

      it 'returns empty array for empty string' do
        result = described_class.call('')
        expect(result).to eq([])
      end
    end

    context 'with context that has no spaces' do
      let(:kwic_text) do
        <<~KWIC
          מילה: word
          ----------------------------------------
          [Test, פסקה 1] [word] 
        KWIC
      end

      it 'handles missing context' do
        result = described_class.call(kwic_text)

        expect(result.length).to eq(1)
        expect(result[0][:instances][0][:before_context]).to eq('')
        expect(result[0][:instances][0][:after_context]).to eq('')
      end
    end
  end
end
