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

    context 'when processing markdown headings with nikkud' do
      it 'does not add > to single # heading lines with nikkud' do
        # Hebrew heading with nikkud (diacritics) - שָׁלוֹם has nikkud marks
        input = "# שָׁלוֹם עֲלֵיכֶם"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('# שָׁלוֹם עֲלֵיכֶם')
      end

      it 'does not add > to ## heading lines with nikkud' do
        input = "## כּוֹתֶרֶת מִשְׁנָה"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('## כּוֹתֶרֶת מִשְׁנָה')
      end

      it 'does not add > to ### heading lines with nikkud' do
        input = "### פֶּרֶק שְׁלִישִׁי"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('### פֶּרֶק שְׁלִישִׁי')
      end

      it 'does not add > to #### heading lines with nikkud' do
        input = "#### סָעִיף רְבִיעִי"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('#### סָעִיף רְבִיעִי')
      end

      it 'does not add > to ##### heading lines with nikkud' do
        input = "##### תַּת־סָעִיף חֲמִישִׁי"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('##### תַּת־סָעִיף חֲמִישִׁי')
      end

      it 'does not add > to ###### heading lines with nikkud' do
        input = "###### רָמָה שִׁשִּׁית"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('###### רָמָה שִׁשִּׁית')
      end

      it 'does not add > to &&& section markers with nikkud' do
        input = "&&& שֵׁם הַיְּצִירָה"
        result = ingestible.postprocess(input)

        expect(result).not_to start_with('>')
        expect(result).to include('&&& שֵׁם הַיְּצִירָה')
      end

      it 'still adds > to regular nikkud text lines' do
        # Regular Hebrew text with nikkud should still get blockquote markers
        input = "שָׁלוֹם עֲלֵיכֶם חֲבֵרִים"
        result = ingestible.postprocess(input)

        expect(result.strip).to start_with('>')
      end
    end
  end

  describe '#title_line' do
    let(:ingestible) { create(:ingestible) }

    it 'returns truthy for single # heading' do
      expect(ingestible.title_line('# Title')).to be_truthy
    end

    it 'returns truthy for ## heading' do
      expect(ingestible.title_line('## Subtitle')).to be_truthy
    end

    it 'returns truthy for ### heading' do
      expect(ingestible.title_line('### Third level')).to be_truthy
    end

    it 'returns truthy for #### heading' do
      expect(ingestible.title_line('#### Fourth level')).to be_truthy
    end

    it 'returns truthy for ##### heading' do
      expect(ingestible.title_line('##### Fifth level')).to be_truthy
    end

    it 'returns truthy for ###### heading' do
      expect(ingestible.title_line('###### Sixth level')).to be_truthy
    end

    it 'returns truthy for &&& section marker' do
      expect(ingestible.title_line('&&& Section')).to be_truthy
    end

    it 'returns falsy for regular text' do
      expect(ingestible.title_line('Regular text')).to be_falsy
    end

    it 'returns falsy for text with # not at start' do
      expect(ingestible.title_line('Text with # hash')).to be_falsy
    end

    it 'returns falsy for # without space after' do
      expect(ingestible.title_line('#NoSpace')).to be_falsy
    end
  end
end
