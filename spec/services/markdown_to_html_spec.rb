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

      it 'adds a Bootstrap popover to each footnote reference' do
        markdown = "Text with footnote[^1] and another[^2].\n\n[^1]: First note.\n\n[^2]: Second note."
        result = described_class.call(markdown)

        # Each reference carries its corresponding note's content (HTML-escaped) in data-content.
        fn1_tag = result[/<a[^>]*href="#fn:1"[^>]*data-toggle="popover"[^>]*>/]
        expect(fn1_tag).not_to be_nil
        expect(CGI.unescapeHTML(fn1_tag[/data-content="([^"]*)"/, 1])).to include('First note.')

        fn2_tag = result[/<a[^>]*href="#fn:2"[^>]*data-toggle="popover"[^>]*>/]
        expect(fn2_tag).not_to be_nil
        expect(CGI.unescapeHTML(fn2_tag[/data-content="([^"]*)"/, 1])).to include('Second note.')
      end

      it 'does not add onclick to footnote reference anchors (navigation is prevented by JS)' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        fn_tag = result[/<a[^>]*href="#fn:1"[^>]*data-toggle="popover"[^>]*>/]
        expect(fn_tag).not_to be_nil
        expect(fn_tag).not_to include('onclick')
      end

      it 'includes a link to the footnote body in the popover footer' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        fn_tag = result[/<a[^>]*href="#fn:1"[^>]*data-toggle="popover"[^>]*>/]
        expect(fn_tag).not_to be_nil
        decoded = CGI.unescapeHTML(fn_tag[/data-content="([^"]*)"/, 1])
        expect(decoded).to include('href="#fn:1"')
        expect(decoded).to include(I18n.t(:footnote_popover_jump_link))
      end

      it 'includes a [x] close link with fn-popover-close class in the popover footer' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        fn_tag = result[/<a[^>]*href="#fn:1"[^>]*data-toggle="popover"[^>]*>/]
        expect(fn_tag).not_to be_nil
        decoded = CGI.unescapeHTML(fn_tag[/data-content="([^"]*)"/, 1])
        expect(decoded).to include('[x]')
        expect(decoded).to include('class="fn-popover-close"')
        expect(decoded).to include(%(aria-label="#{I18n.t(:footnote_popover_close)}"))
        expect(decoded).not_to include('onclick')
      end

      it 'configures the popover for focus-triggered HTML content' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        expect(result).to match(/<a[^>]*href="#fn:1"[^>]*data-trigger="focus"/)
        expect(result).to match(/<a[^>]*href="#fn:1"[^>]*data-html="true"/)
        expect(result).to match(/<a[^>]*href="#fn:1"[^>]*tabindex="0"/)
      end

      it 'omits the popover title by stripping the reference title attribute' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        # The footnote reference must not carry a title attribute, so Bootstrap
        # renders no popover header.
        reference_tag = result[/<a[^>]*href="#fn:1"[^>]*>/]
        expect(reference_tag).not_to be_nil
        expect(reference_tag).not_to include('title=')
      end

      it 'strips the reverse link from popover content but keeps it in the list' do
        markdown = "Text[^1].\n\n[^1]: Note."
        result = described_class.call(markdown)

        # Popover content does not include the back-arrow link.
        reference_tag = result[/<a[^>]*href="#fn:1"[^>]*>/]
        expect(reference_tag).not_to include('reversefootnote')
        # The bottom footnote list still has the reverse link.
        expect(result).to match(%r{<li id="fn:1".*?class="reversefootnote".*?</li>}m)
      end

      it 'HTML-escapes popover content so it is safe inside a data-content attribute' do
        markdown = "Text[^1].\n\n[^1]: A \"quoted\" <em>phrase</em>."
        result = described_class.call(markdown)

        # Extract the value of data-content for the fn:1 reference anchor.
        reference_tag = result[/<a[^>]*href="#fn:1"[^>]*>/]
        data_content = reference_tag[/data-content="([^"]*)"/, 1]
        expect(data_content).not_to be_nil

        # The attribute value itself must not contain raw '<', '>' or '"'
        # characters - those would terminate the attribute or be interpreted
        # as markup when the popover is rendered.
        expect(data_content).not_to include('<')
        expect(data_content).not_to include('>')
        expect(data_content).not_to include('"')

        # And after one level of HTML-entity decoding (what the browser does
        # when reading an attribute), we should see the escaped footnote body
        # that the popover will then render as HTML (data-html="true").
        decoded_once = CGI.unescapeHTML(data_content)
        expect(decoded_once).to include('phrase')
      end

      it 'does not add popover attributes when no footnotes are present' do
        markdown = "# Title\n\nJust a paragraph."
        result = described_class.call(markdown)

        expect(result).not_to include('data-toggle="popover"')
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
        markdown = 'This is [a link](https://example.com) in text.'
        result = described_class.call(markdown)

        expect(result).to include('target="_blank"')
        expect(result).to include('<a href="https://example.com" target="_blank">a link</a>')
      end

      it 'adds target="_blank" to multiple links' do
        markdown = 'First [link one](https://example.com) and [link two](https://another.com).'
        result = described_class.call(markdown)

        expect(result).to include('<a href="https://example.com" target="_blank">link one</a>')
        expect(result).to include('<a href="https://another.com" target="_blank">link two</a>')
      end

      it 'adds target="_blank" to links with existing attributes' do
        markdown = 'Link with [title attribute](https://example.com "Example Site").'
        result = described_class.call(markdown)

        expect(result).to include('target="_blank"')
        expect(result).to include('href="https://example.com"')
      end

      it 'does not add target="_blank" to footnote return links' do
        markdown = "Text with footnote[^1].\n\n[^1]: Footnote content."
        result = described_class.call(markdown)

        # Footnote return links should NOT have target="_blank"
        expect(result).to include('class="reversefootnote"')
        # Ensure that reversefootnote links do not have target="_blank"
        expect(result).not_to match(/<a[^>]*class="reversefootnote"[^>]*target="_blank"/)
        # Footnote reference links should also not have target="_blank"
        expect(result).not_to match(/<a[^>]*href="#fn:1"[^>]*target="_blank"/)
      end

      it 'does not add target="_blank" to internal anchor links' do
        markdown = "See the [introduction](#intro) section.\n\n<a name=\"intro\"></a>\n## Introduction"
        result = described_class.call(markdown)

        # Internal anchor links should NOT have target="_blank"
        expect(result).to include('href="#intro"')
        expect(result).not_to match(/<a[^>]*href="#intro"[^>]*target="_blank"/)
        # Named anchors (without href) should NOT have target="_blank"
        expect(result).to include('<a name="intro"></a>')
        expect(result).not_to match(/<a name="intro"[^>]*target="_blank"/)
      end

      it 'handles links in different contexts' do
        markdown = "# Title\n\nParagraph with [link](https://example.com).\n\n- List item with [link](https://test.com)"
        result = described_class.call(markdown)

        expect(result).to include('<a href="https://example.com" target="_blank">link</a>')
        expect(result).to include('<a href="https://test.com" target="_blank">link</a>')
      end
    end
  end
end
