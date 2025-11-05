# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::DeepSeekParseCitations do
  subject(:result) { described_class.call(html) }

  context 'when html is provided', vcr: { cassette_name: 'lexicon/deepseek_parse_citations' } do
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
        subject: 'על "ארה"',
        authors: 'וויינר, חיים',
        title: '"ארה"',
        from_publication: 'פרקי חיים וספרות / ליקט וכינס זאב וויינר (ירושלים : קרית-ספר, תש"ך 1960)',
        link: nil,
        pages: '89–90',
        notes: 'פורסם לראשונה ב"הדואר", 7 בפברואר 1930'
      }
    end

    let(:expected_attributes_3) do
      {
        subject: 'על "הדמות הקסומה"',
        authors: 'ברוידס, אברהם',
        title: '"הדמות הקסומה" לשמואל בס',
        from_publication: 'דבר, כ"ב באב תש"ז, 8 באוגוסט 1947',
        link: 'http://jpress2.tau.ac.il/Repository/getFiles.asp?Style=OliveXLib:LowLevelEntityToSaveGifMSIE_TAUHE&amp;'\
              'Type=text/html&amp;Locale=hebrew-skin-custom&amp;Path=DAV/1947/08/08&amp;ChunkNum=-1&amp;ID=Ar00702',
        pages: '7',
        notes: nil
      }
    end

    it 'calls DeepSeek and creates LexCitations from it' do
      expect(result.size).to eq(4)
      expect(result).to all(be_a(LexCitation))
      expect(result[0]).to have_attributes(expected_attributes_0)
      expect(result[3]).to have_attributes(expected_attributes_3)
    end
  end
end
