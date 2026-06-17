# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParseCitations do
  subject(:result) { described_class.call(html) }

  context 'when html is provided', vcr: { cassette_name: 'lexicon/parse_citations/00024_snippet' } do
    let(:html) do
      <<~HTML
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000">על "ארה"</font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        <li><b><a href="00019.php">וויינר, חיים.</a></b>&nbsp; "ארה".&nbsp;&nbsp; בספרו: <b>פרקי חיים וספרות</b> / ליקט וכינס זאב וויינר#{' '}
        (ירושלים : קרית-ספר, תש"ך 1960), עמ' 89־90 &lt;פורסם לראשונה ב"הדואר",#{' '}
        7 בפברואר 1930&gt;</li>
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000">על "חופים"</font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        <li><b><a href="01811.php">פנואלי, ש.י.</a></b> [פינלס]&nbsp; "בחופים".&nbsp;
        <u>הארץ</u>, ז' בניסן תרצ"ד, 23 במארס 1934, עמ' 5.</li>
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000">על "בלדות מעבר לנוער"</font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        <li><b><a href="02034.php">בורלא, יהודה.</a></b>
        <a target="_blank" href="http://www.jpress.org.il/Default/Skins/TAUHe/Client.asp?Skin=TAUHe&amp;Enter=True&amp;Ref=REFWLzE5MzgvMTIvMDIjQXIwMDMwNg==&amp;Mode=Gif&amp;Locale=hebrew-skin-custom&amp;AW=1281249519109&amp;AppName=2">"בלדות מעבר לנוער".</a>&nbsp;
        <u>דבר</u>, ט' בכסלו תרצ"ט, 2 בדצמבר 1938, עמ' 3<a target="_blank" href="00024-files/davar19381202.htm">.</a></li>
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000">על "הדמות הקסומה"</font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        <li><b><a href="01063.php">ברוידס, אברהם.</a></b>&nbsp;
        <a target="_blank" href="http://jpress2.tau.ac.il/Repository/getFiles.asp?Style=OliveXLib:LowLevelEntityToSaveGifMSIE_TAUHE&amp;Type=text/html&amp;Locale=hebrew-skin-custom&amp;Path=DAV/1947/08/08&amp;ChunkNum=-1&amp;ID=Ar00702">
        מאצטבת הספרים</a>: "הדמות הקסומה" לשמואל בס.&nbsp; <u>דבר</u>, כ"ב באב#{' '}
        תש"ז, 8 באוגוסט 1947, עמ' 7.</li>
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
        <font color="#FF0000"></font>
        <ul style="MARGIN-TOP: 0in" type="disc">
        </ul>
      HTML
    end

    let(:expected_attributes_0) do
      {
        subject: 'ארה',
        title: 'ארה',
        from_publication: 'פרקי חיים וספרות / ליקט וכינס זאב וויינר (ירושלים : קרית-ספר, תש"ך 1960)',
        link: nil,
        pages: '89־90',
        notes: "פורסם לראשונה ב'הדואר', 7 בפברואר 1930",
        seqno: 1
      }
    end

    let(:expected_attributes_3) do
      {
        subject: 'הדמות הקסומה',
        title: 'הדמות הקסומה לשמואל בס',
        from_publication: 'דבר, כ"ב באב תש"ז, 8 באוגוסט 1947',
        link: 'http://jpress2.tau.ac.il/Repository/getFiles.asp?Style=OliveXLib:LowLevelEntityToSaveGifMSIE_TAUHE&' \
              'Type=text/html&Locale=hebrew-skin-custom&Path=DAV/1947/08/08&ChunkNum=-1&ID=Ar00702',
        pages: '7',
        notes: 'מאצטבת הספרים',
        seqno: 1
      }
    end

    it 'calls AI and creates LexCitations from it' do
      expect(result.size).to eq(4)
      expect(result).to all(be_a(LexCitation))
      expect(result[0]).to have_attributes(expected_attributes_0)
      expect(result[0].authors.length).to eq(1)
      expect(result[0].authors.first).to have_attributes(name: 'וויינר, חיים', link: '00019.php')
      expect(result[3]).to have_attributes(expected_attributes_3)
      expect(result[3].authors.length).to eq(1)
      expect(result[3].authors.first).to have_attributes(name: 'ברוידס, אברהם', link: '01063.php')
    end
  end

  context 'when a citation ends with an asterisk link' do
    let(:html) do
      <<~HTML
        <ul>
          <li><b>מחבר, שם.</b> כותרת המאמר. <u>עיתון</u>, 2024, עמ' 1-5.
            <a href="https://archive.today/abc123">*</a></li>
        </ul>
      HTML
    end

    it 'pre-processes the HTML so the asterisk link href is in data-file-link and the asterisk is removed' do
      chat_double = instance_double(RubyLLM::Chat)
      sent_html = nil

      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask) do |html_arg|
        sent_html = html_arg
        instance_double(RubyLLM::Message, content: {
          result: [{ subject: nil, works: [
            { title: 'כותרת המאמר', authors: [{ name: 'מחבר, שם', link: nil }],
              from_publication: 'עיתון, 2024', pages: '1-5',
              link: nil, backup_url: 'https://archive.today/abc123', notes: nil }
          ] }]
        }.to_json)
      end

      result = described_class.call(html)

      expect(sent_html).to include('data-file-link="https://archive.today/abc123"')
      expect(sent_html).not_to match(%r{<a[^>]*>\s*\*\s*</a>}i)
      expect(result.first.link).to be_nil
      expect(result.first.backup_url).to eq('https://archive.today/abc123')
    end
  end

  context 'when an asterisk link has surrounding whitespace in its text' do
    ['* ', ' *'].each do |text|
      it "treats #{text.inspect} as a backup URL link" do
        html = <<~HTML
          <ul>
            <li>כותרת. עיתון, 2024. <a href="https://archive.today/abc123">#{text}</a></li>
          </ul>
        HTML

        chat_double = instance_double(RubyLLM::Chat)
        sent_html = nil

        allow(RubyLLM).to receive(:chat).and_return(chat_double)
        allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
        allow(chat_double).to receive(:ask) do |html_arg|
          sent_html = html_arg
          instance_double(RubyLLM::Message, content: {
            result: [{ subject: nil, works: [
              { title: 'כותרת', authors: [], from_publication: 'עיתון, 2024',
                pages: nil, link: nil, backup_url: 'https://archive.today/abc123', notes: nil }
            ] }]
          }.to_json)
        end

        result = described_class.call(html)

        expect(sent_html).to include('data-file-link="https://archive.today/abc123"')
        expect(result.first.backup_url).to eq('https://archive.today/abc123')
      end
    end
  end

  context 'when a citation has multiple asterisk links' do
    let(:html) do
      <<~HTML
        <ul>
          <li>כותרת. עיתון, 2024.
            <a href="https://first.example.com/file.pdf">*</a>
            &lt;פורסם גם ב<a href="http://other.example.com/">אתר</a>
            <a href="https://second.example.com/alt.pdf">*</a>&gt;</li>
        </ul>
      HTML
    end

    it 'uses the first asterisk link href as data-file-link' do
      chat_double = instance_double(RubyLLM::Chat)
      sent_html = nil

      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask) do |html_arg|
        sent_html = html_arg
        instance_double(RubyLLM::Message, content: {
          result: [{ subject: nil, works: [
            { title: 'כותרת', authors: [], from_publication: 'עיתון, 2024',
              pages: nil, link: nil, backup_url: 'https://first.example.com/file.pdf', notes: nil }
          ] }]
        }.to_json)
      end

      described_class.call(html)

      expect(sent_html).to include('data-file-link="https://first.example.com/file.pdf"')
      expect(sent_html).not_to include('second.example.com')
    end
  end

  context 'when an asterisk link has a blank href' do
    let(:html) do
      <<~HTML
        <ul>
          <li>כותרת. עיתון, 2024. <a>*</a></li>
        </ul>
      HTML
    end

    it 'removes the asterisk anchor but does not set data-file-link' do
      chat_double = instance_double(RubyLLM::Chat)
      sent_html = nil

      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask) do |html_arg|
        sent_html = html_arg
        instance_double(RubyLLM::Message, content: {
          result: [{ subject: nil, works: [
            { title: 'כותרת', authors: [], from_publication: 'עיתון, 2024',
              pages: nil, link: nil, backup_url: nil, notes: nil }
          ] }]
        }.to_json)
      end

      described_class.call(html)

      expect(sent_html).not_to match(%r{<a[^>]*>\s*\*\s*</a>}i)
      expect(sent_html).not_to include('data-file-link')
    end
  end

  # The LLM frequently omits backup_url even when data-file-link is present, so
  # ParseCitations recovers it deterministically from the asterisk link.
  context 'when the LLM omits backup_url for an asterisk citation' do
    def stub_llm(works)
      chat_double = instance_double(RubyLLM::Chat)
      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: { result: [{ subject: nil, works: works }] }.to_json)
      )
    end

    context 'when the citation has an inline link matching the asterisk <li>' do
      let(:html) do
        <<~HTML
          <ul>
            <li><b>הראל, מעין.</b>
              <a href="https://www.haaretz.co.il/literature/1.1311393">להיות אשה</a>. הארץ, 2008, עמ' 4.
              <a href="/files/lex/5013/00022200.pdf">*</a></li>
          </ul>
        HTML
      end

      it 'recovers backup_url by matching the citation link' do
        stub_llm([
                   { title: 'להיות אשה פירושו להיות חולה', authors: [{ name: 'הראל, מעין', link: nil }],
                     from_publication: 'הארץ, 2008', pages: '4',
                     link: 'https://www.haaretz.co.il/literature/1.1311393', backup_url: nil, notes: nil }
                 ])

        result = described_class.call(html)

        expect(result.first.backup_url).to eq('/files/lex/5013/00022200.pdf')
      end
    end

    context 'when the citation has no inline link' do
      let(:html) do
        <<~HTML
          <ul>
            <li>כותרת ייחודית ארוכה למאמר. עיתון, 2024, עמ' 1-5.
              <a href="/files/lex/5013/00022200.pdf">*</a></li>
          </ul>
        HTML
      end

      it 'recovers backup_url by matching the citation title text' do
        stub_llm([
                   { title: 'כותרת ייחודית ארוכה למאמר', authors: [], from_publication: 'עיתון, 2024',
                     pages: '1-5', link: nil, backup_url: nil, notes: nil }
                 ])

        result = described_class.call(html)

        expect(result.first.backup_url).to eq('/files/lex/5013/00022200.pdf')
      end
    end
  end

  context 'when the LLM returns citations with blank titles' do
    let(:html) { '<ul><li>some html</li></ul>' }

    it 'skips citations with blank titles instead of raising a validation error' do
      chat_double = instance_double(RubyLLM::Chat)
      response_double = instance_double(RubyLLM::Message, content: {
        result: [
          { subject: nil, works: [
            { title: 'כותרת תקינה', authors: [{ name: 'מחבר א', link: nil }],
              from_publication: 'עיתון', pages: '5', link: nil, notes: nil },
            { title: nil, authors: [{ name: 'מחבר ב', link: nil }],
              from_publication: 'עיתון', pages: '6', link: nil, notes: nil },
            { title: '', authors: [{ name: 'מחבר ג', link: nil }],
              from_publication: 'עיתון', pages: '7', link: nil, notes: nil }
          ] }
        ]
      }.to_json)

      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double,
                                             ask: response_double)

      expect(result.size).to eq(1)
      expect(result.first.title).to eq('כותרת תקינה')
    end
  end
end
