# frozen_string_literal: true

require 'rails_helper'

describe MakeHeadingIdsUnique do
  describe '#call' do
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

      it 'replaces IDs with unique sequential IDs' do
        expect(described_class.call(html)).to eq(expected)
      end
    end

    context 'when HTML has no headings' do
      let(:html) { '<p>Just a paragraph</p>' }

      it 'returns the HTML unchanged' do
        expect(described_class.call(html)).to eq(html)
      end
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

      it 'preserves other attributes while changing IDs' do
        expect(described_class.call(html)).to eq(expected)
      end
    end
  end
end
