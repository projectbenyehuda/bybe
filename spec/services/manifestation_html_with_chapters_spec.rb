# frozen_string_literal: true

require 'rails_helper'

describe ManifestationHtmlWithChapters do
  describe '#call' do
    let(:permalink_base_url) { 'http://example.com/read/123' }

    context 'when manifestation has no headings' do
      subject { described_class.call(manifestation, permalink_base_url) }

      let(:markdown) { "# Title\n\nSome content without chapter headings." }
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="title">Title</h1>

          <p>Some content without chapter headings.</p>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns a hash with required keys' do
        expect(subject).to be_a(Hash)
        expect(subject).to have_key(:html)
        expect(subject).to have_key(:chapters)
        expect(subject).to have_key(:selected_chapter)
      end

      it 'returns empty chapters array' do
        expect(subject[:chapters]).to eq([])
      end

      it 'returns nil selected_chapter' do
        expect(subject[:selected_chapter]).to be_nil
      end

      it 'returns expected HTML content' do
        expect(subject[:html].strip).to eq(expected_html)
      end
    end

    context 'when manifestation has chapter headings' do
      subject { described_class.call(manifestation, permalink_base_url) }

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
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-1">🔗</a></span></h2>

          <p>Content of chapter 1</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-2">🔗</a></span></h2>

          <p>Content of chapter 2</p>

          <p><a name="ch8" class="ch_anch" id="ch8">&nbsp;</a></p>

          <h2 id="heading-3">Chapter 3 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-3">🔗</a></span></h2>

          <p>Content of chapter 3</p>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns a hash with required keys' do
        expect(subject).to be_a(Hash)
        expect(subject).to have_key(:html)
        expect(subject).to have_key(:chapters)
        expect(subject).to have_key(:selected_chapter)
      end

      it 'returns expected HTML content' do
        expect(subject[:html].strip).to eq(expected_html)
      end

      it 'returns chapters array with chapter data' do
        chapters = subject[:chapters]
        expect(chapters).to eq([
                                 ['Chapter 1', '2'],
                                 ['Chapter 2', '5'],
                                 ['Chapter 3', '8']
                               ])
      end

      it 'sets selected_chapter to the last chapter' do
        expect(subject[:selected_chapter]).to eq('0003Chapter 1')
      end
    end

    context 'when manifestation has duplicate heading text' do
      subject { described_class.call(manifestation, permalink_base_url) }

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
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-1">🔗</a></span></h2>

          <p>Content of chapter 1 in part 1</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Part 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-2">🔗</a></span></h2>

          <p><a name="ch7" class="ch_anch" id="ch7">&nbsp;</a></p>

          <h2 id="heading-3">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-3">🔗</a></span></h2>

          <p>Content of chapter 1 in part 2</p>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns expected HTML content with unique IDs' do
        expect(subject[:html].strip).to eq(expected_html)
      end

      it 'returns chapters array with both chapters having same title' do
        chapters = subject[:chapters]
        expect(chapters).to eq([
                                 ['Chapter 1', '2'],
                                 ['Part 2', '5'],
                                 ['Chapter 1', '7']
                               ])
      end
    end

    context 'when manifestation has nested headings' do
      subject { described_class.call(manifestation, permalink_base_url) }

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
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-1">🔗</a></span></h2>

          <h3 id="heading-2">Section 1.1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-2">🔗</a></span></h3>

          <p>Content</p>

          <h3 id="heading-3">Section 1.2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-3">🔗</a></span></h3>

          <p>Content</p>

          <p><a name="ch10" class="ch_anch" id="ch10">&nbsp;</a></p>

          <h2 id="heading-4">Chapter 2 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-4">🔗</a></span></h2>

          <h3 id="heading-5">Section 2.1 &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-5">🔗</a></span></h3>

          <p>Content</p>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns expected HTML content with h2 and h3 headings' do
        expect(subject[:html].strip).to eq(expected_html)
      end

      it 'returns chapters array with only h2 headings' do
        chapters = subject[:chapters]
        expect(chapters).to eq([
                                 ['Chapter 1', '2'],
                                 ['Chapter 2', '10']
                               ])
      end
    end

    context 'when manifestation has headings with footnotes' do
      subject { described_class.call(manifestation, permalink_base_url) }

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
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1">Chapter 1<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote"><sup>1</sup></a> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-1">🔗</a></span></h2>

          <p>Content with footnote</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter 2<a href="#fn:2" id="fnref:2" title="see footnote" class="footnote"><sup>2</sup></a> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-2">🔗</a></span></h2>

          <p>More content</p>

          <div class="footnotes">
          <hr />
          <ol>

          <li id="fn:1">
          <span>Footnote 1 <a href="#fnref:1" title="return to body" class="reversefootnote">&#160;&#8617;</a></span>
          </li>

          <li id="fn:2">
          <span>Footnote 2 <a href="#fnref:2" title="return to body" class="reversefootnote">&#160;&#8617;</a></span>
          </li>

          </ol>
          </div>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns expected HTML content with footnotes' do
        expect(subject[:html].strip).to eq(expected_html)
      end

      it 'returns chapters array with sanitized titles (footnotes removed)' do
        chapters = subject[:chapters]
        expect(chapters).to eq([
                                 ['Chapter 1', '2'],
                                 ['Chapter 2', '5']
                               ])
      end
    end

    context 'when manifestation has headings with HTML tags' do
      subject { described_class.call(manifestation, permalink_base_url) }

      let(:markdown) do
        <<~MD
          # Main Title

          ## <em>Emphasized</em> Chapter
          Content

          ## Chapter with <strong>bold</strong>
          Content
        MD
      end
      let(:manifestation) { create(:manifestation, markdown: markdown) }
      let(:expected_html) do
        <<~HTML.strip
          <h1 id="maintitle">Main Title</h1>

          <p><a name="ch2" class="ch_anch" id="ch2">&nbsp;</a></p>

          <h2 id="heading-1"><em>Emphasized</em> Chapter &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-1">🔗</a></span></h2>

          <p>Content</p>

          <p><a name="ch5" class="ch_anch" id="ch5">&nbsp;</a></p>

          <h2 id="heading-2">Chapter with <strong>bold</strong> &nbsp;&nbsp; <span style="font-size: 50%;"><a title="קישור קבוע" href="http://example.com/read/123#heading-2">🔗</a></span></h2>

          <p>Content</p>
        HTML
      end

      before do
        manifestation.recalc_heading_lines!
        manifestation.save!
      end

      it 'returns expected HTML content with HTML tags in headings' do
        expect(subject[:html].strip).to eq(expected_html)
      end

      it 'returns chapters array with sanitized titles (HTML tags stripped)' do
        chapters = subject[:chapters]
        expect(chapters).to eq([
                                 ['Emphasized Chapter', '2'],
                                 ['Chapter with bold', '5']
                               ])
      end
    end
  end
end
