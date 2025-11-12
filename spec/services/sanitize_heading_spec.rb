# frozen_string_literal: true

require 'rails_helper'

describe SanitizeHeading do
  describe '#call' do
    subject { SanitizeHeading.call(heading) }

    context 'when heading contains HTML tags' do
      let(:heading) { '<b>title</b>' }

      it 'strips HTML tags' do
        expect(subject).to eq('title')
      end
    end

    context 'when heading contains nested HTML tags' do
      let(:heading) { '<b><i>title</i></b>' }

      it 'strips all HTML tags' do
        expect(subject).to eq('title')
      end
    end

    context 'when heading contains HTML tags and footnotes' do
      let(:heading) { '<b>title</b>[^ftn1]' }

      it 'strips HTML tags and removes footnotes' do
        expect(subject).to eq('title')
      end
    end

    context 'when heading contains markdown footnotes' do
      let(:heading) { 'title[^1]' }

      it 'removes footnotes' do
        expect(subject).to eq('title')
      end
    end

    context 'when heading contains leading hashes' do
      let(:heading) { '## title' }

      it 'replaces leading hashes with spaces' do
        expect(subject).to eq('&nbsp;&nbsp;&nbsp; title')
      end
    end

    context 'when heading contains escaped quotes' do
      let(:heading) { 'title \"quoted\"' }

      it 'unescapes quotes' do
        expect(subject).to eq('title "quoted"')
      end
    end

    context 'when heading has mixed content' do
      let(:heading) { '## <b>title</b>[^ftn1] \"text\"[^2]' }

      it 'properly sanitizes all elements' do
        expect(subject).to eq('&nbsp;&nbsp;&nbsp; title "text"')
      end
    end

    context 'when heading is plain text' do
      let(:heading) { 'simple title' }

      it 'returns the text unchanged' do
        expect(subject).to eq('simple title')
      end
    end

    context 'when heading has whitespace' do
      let(:heading) { '  title with spaces  ' }

      it 'strips leading and trailing whitespace' do
        expect(subject).to eq('title with spaces')
      end
    end
  end
end
