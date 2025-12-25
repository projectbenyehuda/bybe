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
          chapters: expected_chapters
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
      let(:expected_html) do
        <<~HTML
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-1">🔗</a></span></h2>

          <p>Content with footnote</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter 2<a href="#fn:2" id="fnref:2" title="see footnote" class="footnote"><sup>2</sup></a> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="#{I18n.t(:permalink)}" href="#{permalink_base_url}#heading-2">🔗</a></span></h2>

          <p>More content</p>

          <div class="footnotes">
          <hr />
          <ol>

          <li id="fn:1">
          <span>Footnote 1 <a href="#fnref:1" title="return to body" class="reversefootnote">&#160;&#8617;&#xfe0e;</a></span>
          </li>

          <li id="fn:2">
          <span>Footnote 2 <a href="#fnref:2" title="return to body" class="reversefootnote">&#160;&#8617;&#xfe0e;</a></span>
          </li>

          </ol>
          </div>
        HTML
      end
      let(:expected_chapters) { [['Chapter 1', '2'], ['Chapter 2', '5']] }

      it_behaves_like 'produces expected result'
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

      it_behaves_like 'produces expected result'
    end
  end
end
