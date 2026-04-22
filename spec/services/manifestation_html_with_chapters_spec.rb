# frozen_string_literal: true

require 'rails_helper'

describe ManifestationHtmlWithChapters do
  include Rails.application.routes.url_helpers

  describe '#call' do
    subject(:result) { described_class.call(manifestation) }

    let(:manifestation) { create(:manifestation, markdown: markdown) }
    let(:permalink_base_url) { manifestation_url(manifestation) }

    before do
      manifestation.recalc_heading_lines!
    end

    shared_examples 'produces expected result' do
      it 'returns a hash with expected data' do
        expect(result).to eq(
          html: expected_html,
          chapters: expected_chapters,
          title_footnote: expected_title_footnote
        )
      end
    end

    context 'when manifestation has no headings' do
      let(:markdown) { "# Title\n\nSome content without chapter headings." }
      let(:expected_html) do
        <<~HTML
          <h1 id="title">Title</h1>

          <p>Some content without chapter headings.</p>
        HTML
      end
      let(:expected_chapters) { [] }
      let(:expected_title_footnote) { nil }

      it_behaves_like 'produces expected result'
    end

    context 'when manifestation has chapter headings' do
      let(:markdown) do
        <<~MD
          # Main Title

          ## Chapter 1
          Content of chapter 1

          ## Chapter 2
          Content of chapter 2

          ## Chapter 3
          Content of chapter 3
        MD
      end
      let(:expected_html) do
        <<~HTML
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-1">🔗</a></span></h2>

          <p>Content of chapter 1</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-2">🔗</a></span></h2>

          <p>Content of chapter 2</p>

          <p><a name="ch8" class="ch_anch" id="ch8">&nbsp;</a></p>

          <h2 id="heading-3">Chapter 3 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-3">🔗</a></span></h2>

          <p>Content of chapter 3</p>
        HTML
      end
      let(:expected_chapters) { [['Chapter 1', '2'], ['Chapter 2', '5'], ['Chapter 3', '8']] }
      let(:expected_title_footnote) { nil }

      it_behaves_like 'produces expected result'
    end

    context 'when manifestation has duplicate heading text' do
      let(:markdown) do
        <<~MD
          # Main Title

          ## Chapter 1
          Content of chapter 1 in part 1

          ## Part 2

          ## Chapter 1
          Content of chapter 1 in part 2
        MD
      end
      let(:expected_html) do
        <<~HTML
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-1">🔗</a></span></h2>

          <p>Content of chapter 1 in part 1</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Part 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-2">🔗</a></span></h2>

          <p><a name="ch7" class="ch_anch" id="ch7">&nbsp;</a></p>

          <h2 id="heading-3">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-3">🔗</a></span></h2>

          <p>Content of chapter 1 in part 2</p>
        HTML
      end
      let(:expected_chapters) { [['Chapter 1', '2'], ['Part 2', '5'], ['Chapter 1', '7']] }
      let(:expected_title_footnote) { nil }

      it_behaves_like 'produces expected result'
    end

    context 'when manifestation has nested headings' do
      let(:markdown) do
        <<~MD
          # Main Title

          ## Chapter 1

          ### Section 1.1
          Content

          ### Section 1.2
          Content

          ## Chapter 2

          ### Section 2.1
          Content
        MD
      end
      let(:expected_html) do
        <<~HTML
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-1">🔗</a></span></h2>

          <h3 id="heading-2">Section 1.1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-2">🔗</a></span></h3>

          <p>Content</p>

          <h3 id="heading-3">Section 1.2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-3">🔗</a></span></h3>

          <p>Content</p>

          <p><a name="ch10" class="ch_anch" id="ch10">&nbsp;</a></p>

          <h2 id="heading-4">Chapter 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-4">🔗</a></span></h2>

          <h3 id="heading-5">Section 2.1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-5">🔗</a></span></h3>

          <p>Content</p>
        HTML
      end
      let(:expected_chapters) { [['Chapter 1', '2'], ['Chapter 2', '10']] }
      let(:expected_title_footnote) { nil }

      it_behaves_like 'produces expected result'
    end

    context 'when manifestation has headings with footnotes' do
      let(:markdown) do
        <<~MD
          # Main Title

          ## Chapter 1[^1]
          Content with footnote

          ## Chapter 2[^ftn2]
          More content

          [^1]: Footnote 1
          [^ftn2]: Footnote 2
        MD
      end
      let(:expected_chapters) { [['Chapter 1', '2'], ['Chapter 2', '5']] }

      # Footnote reference anchors are now decorated with Bootstrap popover
      # attributes by MarkdownToHtml, so we check key structural properties
      # rather than the exact anchor markup (which includes a long data-content).
      it 'returns chapters and nil title_footnote' do
        expect(result[:chapters]).to eq(expected_chapters)
        expect(result[:title_footnote]).to be_nil
      end

      it 'includes chapter headings in the html' do
        expect(result[:html]).to include('<h2 id="heading-1">Chapter 1')
        expect(result[:html]).to include('<h2 id="heading-2">Chapter 2')
      end

      it 'decorates heading footnote anchors with popover attributes, not plain title' do
        expect(result[:html]).to include('href="#fn:1"')
        expect(result[:html]).to include('href="#fn:2"')
        expect(result[:html]).to include('data-toggle="popover"')
        expect(result[:html]).not_to include('title="see footnote"')
      end

      it 'preserves the footnote list at the bottom' do
        expect(result[:html]).to include('<span>Footnote 1')
        expect(result[:html]).to include('<span>Footnote 2')
      end
    end

    context 'when manifestation has headings with HTML tags' do
      let(:markdown) do
        <<~MD
          # Main Title

          ## <em>Emphasized</em> Chapter
          Content

          ## Chapter with <strong>bold</strong>
          Content
        MD
      end
      let(:expected_html) do
        <<~HTML
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1"><em>Emphasized</em> Chapter &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-1">🔗</a></span></h2>

          <p>Content</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter with <strong>bold</strong> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-2">🔗</a></span></h2>

          <p>Content</p>
        HTML
      end
      let(:expected_chapters) { [['Emphasized Chapter', '2'], ['Chapter with bold', '5']] }
      let(:expected_title_footnote) { nil }

      it_behaves_like 'produces expected result'
    end

    context 'when markdown starts with standalone footnote reference' do
      let(:markdown) do
        <<~MD
          [^ftn1]

          The quick brown fox jumps over the lazy dog.

          [^ftn1]: This is a footnote at the beginning
        MD
      end
      let(:expected_html) do
        <<~HTML.strip
          <p>The quick brown fox jumps over the lazy dog.</p>

          <div class="footnotes">
          <hr />
          <ol>

          <li id="fn:1">
          <span>This is a footnote at the beginning <a href="#fnref:1" title="return to body" class="reversefootnote">&#160;&#8617;&#xfe0e;</a></span>
          </li>

          </ol>
          </div>
        HTML
      end
      let(:expected_chapters) { [] }

      it 'returns the correct html and chapters' do
        expect(result[:html]).to eq(expected_html)
        expect(result[:chapters]).to eq(expected_chapters)
      end

      # title_footnote is the extracted footnote anchor, now decorated with popover
      # attributes by MarkdownToHtml. We check key properties rather than exact markup
      # because the data-content attribute is long and an implementation detail.
      it 'extracts the standalone footnote as a popover-decorated anchor' do
        title_fn = result[:title_footnote]
        expect(title_fn).not_to be_nil
        expect(title_fn).to include('href="#fn:1"')
        expect(title_fn).to include('class="footnote"')
        expect(title_fn).to include('data-toggle="popover"')
        expect(title_fn).not_to include('title="see footnote"')
      end
    end
  end
end
