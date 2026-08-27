# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParseCitations do
  subject(:result) { described_class.call(html) }

  # `sent` collects the HTML actually handed to the LLM, so specs can assert on it. Each
  # successive request is answered with the next of `groups` — the batched path issues one
  # request per subject heading, so one group per heading.
  def stub_llm_groups(groups, sent = [])
    chat_double = instance_double(RubyLLM::Chat)
    allow(RubyLLM).to receive(:chat).and_return(chat_double)
    allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
    pending = groups.dup
    allow(chat_double).to receive(:ask) do |html_arg|
      sent << html_arg
      instance_double(RubyLLM::Message, content: { result: [pending.shift].compact }.to_json)
    end
  end

  # The single-request form: the one request is answered with a single unnamed group of `works`.
  def stub_llm_capturing(works, sent = [])
    stub_llm_groups([{ subject: nil, works: works }], sent)
  end

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

  # Regression: legacy pages nest a sub-list of citations inside the <li> of the work
  # they are about (e.g. 00156.php). The outer <li> used to swallow the nested
  # citation's asterisk link, so the backup file was attributed both to the work and
  # to the first nested citation carrying an inline link — and never to its real owner.
  context 'when an asterisk link sits in a <li> nested inside another <li>' do
    let(:html) do
      <<~HTML
        <ul>
          <li><b>גרץ, נורית.</b> <b>על דעת עצמו</b> : ארבעה פרקי חיים של עמוס קינן (תל־אביב : עם עובד, 2008)
            <font color="#FF0000">על הספר:</font>
            <ul>
              <li><b>גלסנר, אריק.</b> <a href="http://www.nrg.co.il/online/5/ART1/807/536.html">עד הקצה.</a>
                מעריב, 2008, עמ' 28.</li>
              <li><b>Keydar, Renana.</b> כותרת ייחודית ארוכה של המאמר. Jewish social studies, 2012, pp. 212-224.
                <a href="/files/lex/5181/00156200.pdf">*</a></li>
            </ul>
          </li>
        </ul>
      HTML
    end

    let(:works) do
      [
        { title: 'על דעת עצמו', authors: [{ name: 'גרץ, נורית', link: nil }],
          from_publication: 'עם עובד, 2008', pages: nil, link: nil, backup_url: nil, notes: nil },
        { title: 'עד הקצה', authors: [{ name: 'גלסנר, אריק', link: nil }],
          from_publication: 'מעריב, 2008', pages: '28',
          link: 'http://www.nrg.co.il/online/5/ART1/807/536.html', backup_url: nil, notes: nil },
        { title: 'כותרת ייחודית ארוכה של המאמר', authors: [{ name: 'Keydar, Renana', link: nil }],
          from_publication: 'Jewish social studies, 2012', pages: '212-224',
          link: nil, backup_url: nil, notes: nil }
      ]
    end

    it 'assigns backup_url only to the nested citation the asterisk belongs to' do
      stub_llm_capturing(works)

      result = described_class.call(html)

      expect(result.map(&:backup_url)).to eq([nil, nil, '/files/lex/5181/00156200.pdf'])
    end

    it 'marks data-file-link on the nested <li> only, not on the containing work' do
      sent = []
      stub_llm_capturing(works, sent)

      described_class.call(html)

      doc = Nokogiri::HTML::DocumentFragment.parse(sent.first)
      tagged = doc.css('li[data-file-link]')
      expect(tagged.size).to eq(1)
      # The outer <li> contains the nested one, so identify the tagged <li> by what it
      # does NOT contain: the containing work, and any nested citation of its own.
      expect(tagged.first.css('li')).to be_empty
      expect(tagged.first.text).to include('Keydar, Renana')
      expect(tagged.first.text).not_to include('גרץ, נורית')
    end
  end

  # The LLM reports at most one link per citation, so a link sitting elsewhere in the record
  # (typically on the publication the citation appeared in) used to be dropped entirely.
  context 'when a citation carries an inline link the LLM did not report' do
    def stub_llm(works)
      chat_double = instance_double(RubyLLM::Chat)
      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: { result: [{ subject: nil, works: works }] }.to_json)
      )
    end

    let!(:publication_entry) { create(:lex_file, :publication, title: 'שדות ומזוודות').lex_entry }
    let!(:author_entry) { create(:lex_file, :person, title: 'אברהם עוז').lex_entry }

    let(:html) do
      <<~HTML
        <ul>
          <li><b><a href="/lex/entries/#{author_entry.id}">עוז, אברהם.</a></b> כל העסק מתפרק בכלל :
            הרומן האבוד של עמוס קינן והתיאטרון. בספרו:
            <b><a href="/lex/entries/#{publication_entry.id}">שדות ומזוודות</a></b> : תזות על הדרמה
            (תל־אביב : רסלינג, 2014), עמ' 173–185.</li>
        </ul>
      HTML
    end

    let(:works) do
      [
        { title: 'כל העסק מתפרק בכלל : הרומן האבוד של עמוס קינן והתיאטרון',
          authors: [{ name: 'עוז, אברהם', link: "/lex/entries/#{author_entry.id}" }],
          from_publication: 'בספרו: שדות ומזוודות : תזות על הדרמה (תל־אביב : רסלינג, 2014)',
          pages: '173–185', link: nil, backup_url: nil, notes: nil }
      ]
    end

    it 'stores it as a text link on the citation it came from' do
      stub_llm(works)

      result = described_class.call(html)

      expect(result.first.text_links).to eq([{ 'text' => 'שדות ומזוודות', 'entry_id' => publication_entry.id }])
    end

    it 'does not duplicate an author link as a text link' do
      stub_llm(works)

      result = described_class.call(html)

      expect(result.first.text_links.pluck('text')).not_to include('עוז, אברהם.')
    end

    it 'does not duplicate the citation own link as a text link' do
      stub_llm([works.first.merge(link: "/lex/entries/#{publication_entry.id}")])

      result = described_class.call(html)

      expect(result.first.text_links).to be_nil
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

  # Regression: in files such as 00072.php a citation of an untitled review is written with the
  # placeholder "[ביקורת]" as the <li>'s only bold content and no author at all. The LLM reads
  # that bold slot as the author and returns a null title, so the record — publication, pages,
  # subject and all — used to be dropped silently by the blank-title guard.
  context 'when the LLM reports a bracketed placeholder as the author of a title-less citation' do
    let(:html) do
      <<~HTML
        <font color="#FF0000">על ״רק צרות״</font>
        <ul style="margin-top:0in" type="circle">
        <li> <b>[ביקורת].</b> <u>ספרות ילדים ונוער</u>, כרך י״ד, גל' ב' (1988), עמ' 63־64. </li>
        </ul>
      HTML
    end

    let(:works) do
      [
        { title: nil, authors: [{ name: '[ביקורת]', link: nil }],
          from_publication: 'ספרות ילדים ונוער, כרך י״ד, גל\' ב\' (1988)', pages: '63־64',
          link: nil, backup_url: nil, notes: nil }
      ]
    end

    def stub_llm(works)
      chat_double = instance_double(RubyLLM::Chat)
      allow(RubyLLM).to receive(:chat).and_return(chat_double)
      allow(chat_double).to receive_messages(with_instructions: chat_double, with_params: chat_double)
      allow(chat_double).to receive(:ask).and_return(
        instance_double(RubyLLM::Message, content: { result: [{ subject: 'רק צרות', works: works }] }.to_json)
      )
    end

    it 'keeps the citation, promoting the placeholder to its title' do
      stub_llm(works)

      expect(result.size).to eq(1)
      expect(result.first).to have_attributes(
        subject: 'רק צרות',
        title: '[ביקורת]',
        pages: '63־64'
      )
    end

    it 'does not leave the placeholder behind as an author' do
      stub_llm(works)

      expect(result.first.authors).to be_empty
    end

    it 'produces a citation that passes validation' do
      stub_llm(works)

      citation = result.first
      citation.person = build(:lex_person)
      expect(citation).to be_valid
    end

    it 'leaves a bracketed author accompanying a real title alone' do
      stub_llm([works.first.merge(title: 'שיחה עם הסופרת', authors: [{ name: '[יעוז, חנה]', link: nil }])])

      expect(result.first.title).to eq('שיחה עם הסופרת')
      expect(result.first.authors.map(&:name)).to eq(['[יעוז, חנה]'])
    end

    it 'still skips a title-less citation whose sole author is a real name' do
      stub_llm([works.first.merge(authors: [{ name: 'ברגסון, גרשון', link: nil }])])

      expect(result).to be_empty
    end

    it 'still skips a title-less citation carrying more than one author' do
      stub_llm([works.first.merge(authors: [{ name: '[ביקורת]', link: nil }, { name: 'ברגסון, גרשון', link: nil }])])

      expect(result).to be_empty
    end

    # A bracketed author that links to a lexicon entry is a real entry reference, not a
    # placeholder; promoting its name to the title would throw the link away.
    it 'still skips a title-less citation whose bracketed author carries a link' do
      stub_llm([works.first.merge(authors: [{ name: '[סדן, דב]', link: '02402.php' }])])

      expect(result).to be_empty
    end
  end

  # Regression: a bibliography too long for one model response (00540.php has 202 records) came
  # back with every subject header but only the first work or two of the later groups, so most of
  # it was lost. Past the threshold the section is split at its subject headings, one request per
  # heading, and the results aggregated.
  describe 'batching a long bibliography' do
    # The shape legacy pages use: an empty <ul> separator and an <hr> between sections, with the
    # subject in a <font> immediately before its list.
    def bibliography_html(sections)
      sections.map do |heading, items|
        <<~HTML
          <font color="#FF0000"></font>
          <ul style="MARGIN-TOP: 0in" type="disc"></ul>
          <hr>
          <font color="#FF0000">#{heading}</font>
          <ul style="MARGIN-TOP: 0in" type="disc">
          #{items.map { |item| "<li>#{item}</li>" }.join("\n")}
          </ul>
        HTML
      end.join("\n")
    end

    # Numbered so each title is unique and comfortably longer than the eight characters the
    # title-containment fallback in match_by_text requires.
    def title_for(heading, index)
      "כותרת ייחודית #{heading} מספר #{index}"
    end

    def plain_items(heading, count)
      (1..count).map { |i| "<b>מחבר, שם.</b> #{title_for(heading, i)}. עיתון, 2024, עמ' #{i}." }
    end

    def work(title, **overrides)
      { title: title, authors: [], from_publication: 'עיתון, 2024', pages: '1',
        link: nil, backup_url: nil, notes: nil }.merge(overrides)
    end

    def group(heading, count)
      { subject: heading, works: (1..count).map { |i| work(title_for(heading, i)) } }
    end

    def li_texts(batch_html)
      Nokogiri::HTML::DocumentFragment.parse(batch_html).css('li').map { |li| li.text.squish }
    end

    context 'when the bibliography is within the single-request threshold' do
      let(:sections) { { 'על השירה' => 40, 'על הפרוזה' => 40, 'על המחזות' => 40 } }
      let(:html) { bibliography_html(sections.transform_values { |count| plain_items('על השירה', count) }) }

      it 'issues exactly one request, carrying the whole section' do
        sent = []
        stub_llm_capturing(group('על השירה', 40)[:works], sent)

        described_class.call(html)

        expect(sent.size).to eq(1)
        expect(li_texts(sent.first).size).to eq(120)
      end
    end

    context 'when the bibliography exceeds the threshold' do
      let(:sections) { { 'על השירה' => 50, 'על הפרוזה' => 50, 'על המחזות' => 30 } }
      let(:html) { bibliography_html(sections.to_h { |heading, count| [heading, plain_items(heading, count)] }) }
      let(:groups) { sections.map { |heading, count| group(heading, count) } }
      let(:all_titles) { sections.flat_map { |heading, count| (1..count).map { |i| title_for(heading, i) } } }

      it 'issues one request per subject heading' do
        sent = []
        stub_llm_groups(groups, sent)

        described_class.call(html)

        expect(sent.size).to eq(3)
      end

      it 'sends each heading only its own citations, with none dropped or duplicated' do
        sent = []
        stub_llm_groups(groups, sent)

        described_class.call(html)

        batches = sent.map { |batch| li_texts(batch) }
        expect(batches.map(&:size)).to eq([50, 50, 30])
        expect(batches.flatten.uniq.size).to eq(130)
        expect(sent.first).to include(title_for('על השירה', 1))
        expect(sent.first).not_to include('על הפרוזה')
      end

      it 'returns the citations of every batch, in batch order' do
        stub_llm_groups(groups)

        expect(result.map(&:title)).to eq(all_titles)
      end

      it 'carries each batch subject onto its citations' do
        stub_llm_groups(groups)

        expect(result.map(&:subject).tally).to eq('על השירה' => 50, 'על הפרוזה' => 50, 'על המחזות' => 30)
      end

      it 'restarts seqno within each subject' do
        stub_llm_groups(groups)

        expect(result.map(&:seqno)).to eq([*1..50, *1..50, *1..30])
      end

      it 'skips a blank-titled citation without disturbing the other batches' do
        blanked = groups.dup
        blanked[1] = { subject: 'על הפרוזה',
                       works: groups[1][:works].map.with_index { |w, i| i == 3 ? w.merge(title: nil) : w } }
        stub_llm_groups(blanked)

        expect(result.size).to eq(129)
        expect(result.map(&:subject).tally['על הפרוזה']).to eq(49)
      end
    end

    # recover_backup_urls and assign_text_links run once over the aggregate rather than per batch,
    # so both have to find citations that were parsed by a request other than the first.
    context 'when an asterisk link sits in a later batch' do
      let(:sections) { { 'על השירה' => 60, 'על הפרוזה' => 60, 'על המחזות' => 10 } }
      let(:groups) { sections.map { |heading, count| group(heading, count) } }
      let(:html) do
        items = sections.to_h { |heading, count| [heading, plain_items(heading, count)] }
        items['על המחזות'][6] += ' <a href="/files/lex/5013/00022200.pdf">*</a>'
        bibliography_html(items)
      end

      it 'recovers backup_url for the citation in that batch' do
        stub_llm_groups(groups)

        expect(result.size).to eq(130)
        expect(result.select(&:backup_url).map(&:title)).to eq([title_for('על המחזות', 7)])
        expect(result.find(&:backup_url).backup_url).to eq('/files/lex/5013/00022200.pdf')
      end
    end

    context 'when inline links sit in citations of different batches' do
      let(:sections) { { 'על השירה' => 60, 'על הפרוזה' => 60, 'על המחזות' => 10 } }
      let(:groups) { sections.map { |heading, count| group(heading, count) } }
      let(:html) do
        items = sections.to_h { |heading, count| [heading, plain_items(heading, count)] }
        items['על השירה'][0] += ' <a href="https://example.com/first">כתב-עת ראשון</a>'
        items['על המחזות'][0] += ' <a href="https://example.com/last">כתב-עת אחרון</a>'
        bibliography_html(items)
      end

      it 'assigns each text link to the citation it came from' do
        stub_llm_groups(groups)

        expect(result.find { |c| c.title == title_for('על השירה', 1) }.text_links)
          .to eq([{ 'url' => 'https://example.com/first', 'text' => 'כתב-עת ראשון' }])
        expect(result.find { |c| c.title == title_for('על המחזות', 1) }.text_links)
          .to eq([{ 'url' => 'https://example.com/last', 'text' => 'כתב-עת אחרון' }])
        expect(result.count { |c| c.text_links.present? }).to eq(2)
      end
    end

    # ExtractCitations admits a bare <li>, which belongs to no subject list and so would be lost
    # by batching. Rather than drop it, fall back to the single request.
    context 'when a bare <li> sits outside any list' do
      let(:html) do
        "#{bibliography_html('על השירה' => plain_items('על השירה', 121))}\n<li>ציטוט יתום ארוך דיו</li>"
      end

      it 'falls back to a single request' do
        sent = []
        stub_llm_capturing(group('על השירה', 121)[:works], sent)

        described_class.call(html)

        expect(sent.size).to eq(1)
        expect(sent.first).to include('ציטוט יתום ארוך דיו')
      end
    end

    context 'when the bibliography has no list at all' do
      let(:html) { (1..121).map { |i| "<li>כותרת ייחודית מספר #{i}</li>" }.join("\n") }

      it 'falls back to a single request' do
        sent = []
        stub_llm_capturing([work('כותרת ייחודית מספר 1')], sent)

        described_class.call(html)

        expect(sent.size).to eq(1)
        expect(li_texts(sent.first).size).to eq(121)
      end
    end

    # A sub-list of citations nested inside the <li> of the work they are about (00156.php) must
    # travel with that <li>, not become a batch of its own.
    context 'when a citation contains a nested sub-list' do
      let(:nested_item) do
        <<~HTML.squish
          <b>גרץ, נורית.</b> <b>על דעת עצמו</b> (תל־אביב : עם עובד, 2008)
          <font color="#FF0000">על הספר:</font>
          <ul>
            <li><b>גלסנר, אריק.</b> כותרת ייחודית מקוננת ראשונה. מעריב, 2008, עמ' 28.</li>
            <li><b>Keydar, Renana.</b> כותרת ייחודית מקוננת שנייה. Jewish social studies, 2012, pp. 212-224.
              <a href="/files/lex/5181/00156200.pdf">*</a></li>
          </ul>
        HTML
      end

      let(:html) do
        bibliography_html('על השירה' => plain_items('על השירה', 60),
                          'על הפרוזה' => plain_items('על הפרוזה', 60),
                          'על הספרים' => [nested_item])
      end

      let(:groups) do
        [group('על השירה', 60), group('על הפרוזה', 60),
         { subject: 'על הספרים',
           works: [work('על דעת עצמו'), work('כותרת ייחודית מקוננת ראשונה'), work('כותרת ייחודית מקוננת שנייה')] }]
      end

      it 'keeps the outer <li> and its nested citations in one batch' do
        sent = []
        stub_llm_groups(groups, sent)

        result = described_class.call(html)

        expect(sent.size).to eq(3)
        expect(li_texts(sent.last).size).to eq(3)
        expect(result.select(&:backup_url).map(&:title)).to eq(['כותרת ייחודית מקוננת שנייה'])
      end

      it 'still tags data-file-link on the nested <li> only' do
        sent = []
        stub_llm_groups(groups, sent)

        described_class.call(html)

        tagged = Nokogiri::HTML::DocumentFragment.parse(sent.last).css('li[data-file-link]')
        expect(tagged.size).to eq(1)
        expect(tagged.first.css('li')).to be_empty
        expect(tagged.first.text).to include('Keydar, Renana')
      end
    end
  end
end
