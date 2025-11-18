# frozen_string_literal: true

require 'rails_helper'

describe SanitizeHeading do
  subject { described_class.call(heading) }

  context 'when heading contains HTML tags' do
    let(:heading) { '<b>title</b>' }

    it { is_expected.to eq('title') }
  end

  context 'when heading contains nested HTML tags' do
    let(:heading) { '<b><i>title</i></b>' }

    it { is_expected.to eq('title') }
  end

  context 'when heading contains HTML tags and footnotes' do
    let(:heading) { '<b>title</b>[^ftn1]' }

    it { is_expected.to eq('title') }
  end

  context 'when heading contains markdown footnotes' do
    let(:heading) { 'title[^1]' }

    it { is_expected.to eq('title') }
  end

  context 'when heading contains leading hashes' do
    let(:heading) { '## title' }

    it { is_expected.to eq('&nbsp;&nbsp;&nbsp; title') }
  end

  context 'when heading contains escaped quotes' do
    let(:heading) { 'title \"quoted\"' }

    it { is_expected.to eq('title "quoted"') }
  end

  context 'when heading has mixed content' do
    let(:heading) { '## <b>title</b>[^ftn1] \"text\"[^2]' }

    it { is_expected.to eq('&nbsp;&nbsp;&nbsp; title "text"') }
  end

  context 'when heading is plain text' do
    let(:heading) { 'simple title' }

    it { is_expected.to eq('simple title') }
  end

  context 'when heading has whitespace' do
    let(:heading) { '  title with spaces  ' }

    it { is_expected.to eq('title with spaces') }
  end
end
