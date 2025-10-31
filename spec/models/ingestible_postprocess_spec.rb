# frozen_string_literal: true

require 'rails_helper'

describe Ingestible do
  describe '#postprocess' do
    let(:ingestible) { create(:ingestible) }

    context 'when processing HTML tags from pandoc' do
      it 'removes div tags' do
        input = "<div>Some text</div>"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<div>')
        expect(result).not_to include('</div>')
        expect(result).to include('Some text')
      end

      it 'removes paragraph tags' do
        input = "<p>Paragraph text</p>"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<p>')
        expect(result).not_to include('</p>')
        expect(result).to include('Paragraph text')
      end

      it 'removes anchor tags' do
        input = '<a href="http://example.com">Link text</a>'
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<a')
        expect(result).not_to include('</a>')
        expect(result).to include('Link text')
      end

      it 'removes strong/bold tags' do
        input = "<strong>Bold text</strong>"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<strong>')
        expect(result).not_to include('</strong>')
        expect(result).to include('Bold text')
      end

      it 'removes multiple types of HTML tags' do
        input = "<div><p>Text with <strong>bold</strong> and <em>italic</em></p></div>"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<div>')
        expect(result).not_to include('<p>')
        expect(result).not_to include('<strong>')
        expect(result).not_to include('<em>')
        expect(result).to include('Text with bold and italic')
      end

      it 'preserves <br /> tags for poetry formatting' do
        input = "Line one<br />Line two"
        result = ingestible.postprocess(input)
        
        expect(result).to include('<br />')
      end

      it 'preserves <br> tag variations' do
        input = "Line<br>Line<br />Line<br/>End"
        result = ingestible.postprocess(input)
        
        expect(result).to include('<br>')
        expect(result).to include('<br />')
        expect(result).to include('<br/>')
      end

      it 'removes <b> tags but not <br> tags' do
        input = "Text <b>bold</b> and <br> break"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<b>')
        expect(result).not_to include('</b>')
        expect(result).to include('<br>')
        expect(result).to include('Text bold and <br> break')
      end

      it 'preserves legitimate < characters in mathematical expressions' do
        input = "המחיר < 100 שקלים"
        result = ingestible.postprocess(input)
        
        # The < that's not part of a tag should be preserved
        expect(result).to include('< 100')
      end

      it 'handles HTML tags in the middle of text' do
        input = "This is a <div>sentence with</div> a div tag in the middle"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<div>')
        expect(result).not_to include('</div>')
        expect(result).to eq("This is a sentence with a div tag in the middle")
      end
    end

    context 'when processing lines with nikkud' do
      it 'adds blockquote marker to poetry lines with nikkud' do
        # Hebrew text with nikkud (vowel points) - typical poetry
        input = "שִׁיר הַשִּׁירִים\nשִׁיר שֵׁנִי"
        result = ingestible.postprocess(input)
        
        # Each line should be prefixed with >
        expect(result).to include('> שִׁיר הַשִּׁירִים')
        expect(result).to include('> שִׁיר שֵׁנִי')
      end
    end

    context 'when processing lines without nikkud' do
      it 'does not add blockquote marker to regular text' do
        input = "זה טקסט רגיל\nבלי נקודות"
        result = ingestible.postprocess(input)
        
        # Should not have > prefix (except possibly if there's a <br /> tag)
        lines = result.split("\n")
        regular_lines = lines.reject { |l| l.include?('<br') }
        regular_lines.each do |line|
          expect(line).not_to start_with('>')
        end
      end
    end

    context 'when processing span tags' do
      it 'removes span tags as before' do
        input = "<span>Text in span</span>"
        result = ingestible.postprocess(input)
        
        expect(result).not_to include('<span>')
        expect(result).not_to include('</span>')
        expect(result).to include('Text in span')
      end
    end
  end
end
