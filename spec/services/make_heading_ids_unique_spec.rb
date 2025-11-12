# frozen_string_literal: true

require 'rails_helper'

describe MakeHeadingIdsUnique do
  describe '#call' do
    subject { MakeHeadingIdsUnique.call(html) }

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

      it 'replaces IDs with unique sequential IDs' do
        result = subject
        # Extract all heading IDs
        heading_ids = result.scan(/<h[23][^>]*id="([^"]+)"/).flatten
        # Verify all IDs are unique
        expect(heading_ids.uniq.length).to eq(heading_ids.length)
        # Verify IDs follow the expected pattern
        expect(heading_ids).to match_array(%w[heading-1 heading-2 heading-3])
        # Verify heading content is preserved
        expect(result).to include('Chapter 1')
        expect(result).to include('Section')
      end
    end

    context 'when HTML has no headings' do
      let(:html) { '<p>Just a paragraph</p>' }

      it 'returns the HTML unchanged' do
        expect(subject).to eq(html)
      end
    end

    context 'when HTML has headings with attributes' do
      let(:html) do
        <<~HTML
          <h2 class="title" id="old-id" data-value="test">Heading</h2>
          <h3 style="color:red" id="another-id">Subheading</h3>
        HTML
      end

      it 'preserves other attributes while changing IDs' do
        result = subject
        expect(result).to include('class="title"')
        expect(result).to include('data-value="test"')
        expect(result).to include('style="color:red"')
        expect(result).to include('id="heading-1"')
        expect(result).to include('id="heading-2"')
        expect(result).not_to include('old-id')
        expect(result).not_to include('another-id')
      end
    end
  end
end
