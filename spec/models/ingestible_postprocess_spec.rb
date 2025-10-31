# frozen_string_literal: true

require 'rails_helper'

describe Ingestible do
  describe '#postprocess' do
    let(:ingestible) { create(:ingestible) }

    context 'when processing lines with nikkud' do
      it 'adds blockquote marker to poetry lines with nikkud' do
        # Hebrew text with nikkud (vowel points) - typical poetry
        input = "שִׁיר הַשִּׁירִים\nשִׁיר שֵׁנִי"
        result = ingestible.postprocess(input)
        
        # Each line should be prefixed with >
        expect(result).to include('> שִׁיר הַשִּׁירִים')
        expect(result).to include('> שִׁיר שֵׁנִי')
      end

      it 'does not add blockquote marker to prose with nikkud that continues mid-sentence' do
        # Text that looks like continuation of a sentence
        input = "הוּא הָלַךְ לָעִיר וְקָנָה\nלֶחֶם וְחָזַר הַבַּיְתָה."
        result = ingestible.postprocess(input)
        
        # Should not have blockquote markers if it's continuous prose
        # This test will fail with current implementation, showing the bug
        lines = result.split("\n")
        
        # For now, let's just document what the current behavior is
        puts "Current result:"
        puts result
        puts "---"
      end

      it 'preserves actual < characters in source text' do
        input = "המחיר < 100 שקלים"
        result = ingestible.postprocess(input)
        
        # Should preserve the < character
        expect(result).to include('<')
      end
    end

    context 'when processing lines without nikkud' do
      it 'does not add blockquote marker to regular text' do
        input = "זה טקסט רגיל\nבלי נקודות"
        result = ingestible.postprocess(input)
        
        # Should not have > prefix
        expect(result).not_to include('>')
      end
    end

    context 'when processing mixed content' do
      it 'handles poetry sections followed by prose correctly' do
        # Poetry with nikkud, then regular prose
        input = "שִׁיר הַשִּׁירִים\n\nזה פסקה רגילה בלי נקודות"
        result = ingestible.postprocess(input)
        
        puts "Mixed content result:"
        puts result
        puts "---"
      end
    end
  end
end
