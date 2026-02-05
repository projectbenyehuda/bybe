# frozen_string_literal: true

require 'rails_helper'

describe ExtractFirstFootnoteReference do
  describe '#call' do
    subject(:result) { described_class.call(markdown, html) }

    context 'when markdown starts with standalone footnote reference' do
      let(:markdown) do
        <<~MD
          [^ftn1]

          The quick brown fox.

          [^ftn1]: Footnote text
        MD
      end
      let(:html) do
        <<~HTML
          <p><a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a></p>

          <p>The quick brown fox.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Footnote text</span>
          </li>
          </ol>
          </div>
        HTML
      end
      let(:expected_cleaned_html) do
        <<~HTML.strip
          <p>The quick brown fox.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Footnote text</span>
          </li>
          </ol>
          </div>
        HTML
      end

      it 'extracts the footnote link and removes it from HTML' do
        expected_link = '<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a>'
        expect(result[:footnote_html]).to eq(expected_link)
        expect(result[:cleaned_html].strip).to eq(expected_cleaned_html)
      end
    end

    context 'when markdown does not start with footnote reference' do
      let(:markdown) { 'The quick brown fox.' }
      let(:html) { '<p>The quick brown fox.</p>' }

      it 'returns nil for footnote_html and original HTML' do
        expect(result[:footnote_html]).to be_nil
        expect(result[:cleaned_html]).to eq(html)
      end
    end

    context 'when first line has text before footnote reference' do
      let(:markdown) do
        <<~MD
          Some text [^1]

          More content.

          [^1]: Footnote
        MD
      end
      let(:html) do
        <<~HTML
          <p>Some text <a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a></p>

          <p>More content.</p>
        HTML
      end

      it 'does not extract the footnote' do
        expect(result[:footnote_html]).to be_nil
        expect(result[:cleaned_html]).to eq(html)
      end
    end

    context 'when markdown starts with whitespace then footnote reference' do
      let(:markdown) do
        <<~MD

          [^abc]

          Content here.

          [^abc]: Note
        MD
      end
      let(:html) do
        <<~HTML
          <p><a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a></p>

          <p>Content here.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Note</span>
          </li>
          </ol>
          </div>
        HTML
      end
      let(:expected_cleaned_html) do
        <<~HTML.strip
          <p>Content here.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Note</span>
          </li>
          </ol>
          </div>
        HTML
      end

      it 'extracts the footnote link' do
        expected_link = '<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a>'
        expect(result[:footnote_html]).to eq(expected_link)
        expect(result[:cleaned_html].strip).to eq(expected_cleaned_html)
      end
    end

    context 'when footnote reference is immediately followed by text without blank line' do
      let(:markdown) do
        <<~MD
          [^1]
          The quick brown fox jumps over the lazy dog.

          [^1]: Footnote text here
        MD
      end
      let(:html) do
        <<~HTML
          <p><a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a>The quick brown fox jumps over the lazy dog.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Footnote text here</span>
          </li>
          </ol>
          </div>
        HTML
      end
      let(:expected_cleaned_html) do
        <<~HTML.strip
          <p>The quick brown fox jumps over the lazy dog.</p>

          <div class="footnotes">
          <hr />
          <ol>
          <li id="fn:1">
          <span>Footnote text here</span>
          </li>
          </ol>
          </div>
        HTML
      end

      it 'extracts the footnote link and preserves the following text' do
        expected_link = '<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a>'
        expect(result[:footnote_html]).to eq(expected_link)
        expect(result[:cleaned_html].strip).to eq(expected_cleaned_html)
      end
    end
  end
end
