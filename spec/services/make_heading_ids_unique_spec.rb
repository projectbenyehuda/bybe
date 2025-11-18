# frozen_string_literal: true

require 'rails_helper'

describe MakeHeadingIdsUnique do
  subject(:call) { described_class.call(html) }

  context 'when HTML has headings with duplicate IDs' do
    let(:html) do
      <<~HTML
        <h2 id="chapter-1">Chapter 1</h2>
        <p>Content of first chapter 1</p>
        <h2 id="chapter-1">Chapter 1</h2>
        <p>Content of second chapter 1</p>
        <h3 id="section">Section</h3>
      HTML
    end

    let(:expected) do
      <<~HTML
        <h2 id="heading-1">Chapter 1</h2>
        <p>Content of first chapter 1</p>
        <h2 id="heading-2">Chapter 1</h2>
        <p>Content of second chapter 1</p>
        <h3 id="heading-3">Section</h3>
      HTML
    end

    it { is_expected.to eq(expected) }
  end

  context 'when HTML has no headings' do
    let(:html) { '<p>Just a paragraph</p>' }

    it { is_expected.to eq(html) }
  end

  context 'when HTML has headings with attributes' do
    let(:html) do
      <<~HTML
        <h2 class="title" id="old-id" data-value="test">Heading</h2>
        <h3 style="color:red" id="another-id">Subheading</h3>
      HTML
    end

    let(:expected) do
      <<~HTML
        <h2 class="title" id="heading-1" data-value="test">Heading</h2>
        <h3 style="color:red" id="heading-2">Subheading</h3>
      HTML
    end

    it { is_expected.to eq(expected) }
  end
end
