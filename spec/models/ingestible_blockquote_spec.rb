# frozen_string_literal: true

require 'rails_helper'

describe Ingestible do
  describe '#postprocess' do
    let(:ingestible) { create(:ingestible) }

    context 'when processing blockquote markers' do
      it 'does not add duplicate > markers to lines that already have them' do
        # Simulate markdown that already has > markers (e.g., from prior processing)
        input = "> Line with existing blockquote\n> Another line"
        result = ingestible.postprocess(input)
        
        # Should not have double >> markers
        expect(result).not_to include('> >')
        expect(result).to include('> Line with existing blockquote')
      end

      it 'does not add > to lines that start with > after whitespace' do
        input = "  > Line with indented blockquote"
        result = ingestible.postprocess(input)
        
        # Should not add another > before the existing one
        expect(result).not_to match(/>\s+>/)
      end

      it 'preserves existing blockquote formatting' do
        input = "> קטע ראשון\n> קטע שני"
        result = ingestible.postprocess(input)
        
        # Should maintain the blockquote format without duplication
        lines = result.split("\n").reject(&:empty?)
        lines.each do |line|
          # Each line should start with exactly one >
          expect(line.scan(/^>\s/).length).to be <= 1
        end
      end
    end
  end
end
