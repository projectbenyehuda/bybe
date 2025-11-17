# frozen_string_literal: true

require 'rails_helper'

describe MarkdownToHtml do
  describe '#call' do
    context 'when markdown is blank' do
      it 'returns empty string' do
        result = MarkdownToHtml.call('')
        expect(result).to eq('')
      end

      it 'returns empty string for nil' do
        result = MarkdownToHtml.call(nil)
        expect(result).to eq('')
      end
    end

    context 'when markdown contains footnotes' do
      it 'converts first paragraph in footnotes to span' do
        markdown = "Text with footnote[^1].\n\n[^1]: This is the footnote content."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<span>This is the footnote content.')
        expect(result).not_to include('<li id="fn:1"><p>This is the footnote content.')
      end

      it 'handles multiple footnotes correctly' do
        markdown = "Text with footnotes[^1] and more[^2].\n\n[^1]: First footnote.\n\n[^2]: Second footnote."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<span>First footnote.')
        expect(result).to include('<span>Second footnote.')
        expect(result).not_to include('<li id="fn:1"><p>First footnote.')
        expect(result).not_to include('<li id="fn:2"><p>Second footnote.')
      end

      it 'only changes first paragraph in multi-paragraph footnotes' do
        markdown = "Text with footnote[^1].\n\n[^1]: First paragraph.\n\n    Second paragraph."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<span>First paragraph.')
        expect(result).to include('<p>Second paragraph.')
      end

      it 'preserves return links in footnotes' do
        markdown = "Text with footnote[^1].\n\n[^1]: Footnote content."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('class="reversefootnote"')
        expect(result).to include('href="#fnref:1"')
      end
    end

    context 'when markdown does not contain footnotes' do
      it 'does not change regular paragraphs' do
        markdown = "# Title\n\nThis is a regular paragraph."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<p>This is a regular paragraph.</p>')
      end
    end

    context 'when markdown contains figcaptions' do
      it 'removes figcaptions' do
        # This test assumes MultiMarkdown generates figcaptions for certain markdown syntax
        # The exact syntax may vary depending on the MultiMarkdown version
        markdown = 'Text content'
        html_with_figcaption = '<p>Text content</p><figcaption>Caption</figcaption>'.dup

        # Mock MultiMarkdown to return HTML with figcaption
        allow_any_instance_of(MultiMarkdown).to receive(:to_html).and_return(html_with_figcaption)

        result = MarkdownToHtml.call(markdown)
        expect(result).not_to include('figcaption')
        expect(result).to include('<p>Text content</p>')
      end
    end

    context 'when markdown contains links' do
      it 'adds target="_blank" to external links' do
        markdown = "This is [a link](https://example.com) in text."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('target="_blank"')
        expect(result).to include('<a href="https://example.com" target="_blank">a link</a>')
      end

      it 'adds target="_blank" to multiple links' do
        markdown = "First [link one](https://example.com) and [link two](https://another.com)."
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<a href="https://example.com" target="_blank">link one</a>')
        expect(result).to include('<a href="https://another.com" target="_blank">link two</a>')
      end

      it 'adds target="_blank" to links with existing attributes' do
        markdown = 'Link with [title attribute](https://example.com "Example Site").'
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('target="_blank"')
        expect(result).to include('href="https://example.com"')
      end

      it 'adds target="_blank" to footnote return links' do
        markdown = "Text with footnote[^1].\n\n[^1]: Footnote content."
        result = MarkdownToHtml.call(markdown)

        # Footnote return links should also have target="_blank"
        expect(result).to include('class="reversefootnote"')
        expect(result).to include('target="_blank"')
      end

      it 'handles links in different contexts' do
        markdown = "# Title\n\nParagraph with [link](https://example.com).\n\n- List item with [link](https://test.com)"
        result = MarkdownToHtml.call(markdown)

        expect(result).to include('<a href="https://example.com" target="_blank">link</a>')
        expect(result).to include('<a href="https://test.com" target="_blank">link</a>')
      end
    end
  end
end
