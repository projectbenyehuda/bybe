# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractPersonWorks do
  subject!(:result) { described_class.call(works_header, lex_person) }

  let(:html_doc) { Nokogiri::HTML(html) }
  let(:works_header) { html_doc.css('p, font').find { |e| e.at_css('a[name="Books"]') } }
  let(:lex_person) { LexPerson.new }

  context 'when works list has no span wrapper' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <ul>
          <li>ספר ראשון (תל אביב : דביר, 1990)</li>
          <li>ספר שני (ירושלים : כתר, 2000)</li>
        </ul>
        <p><a name="Bib.">על המחבר:</a></p>
      HTML
    end

    it 'extracts all original works and returns next element' do
      expect(lex_person.works.size).to eq(2)
      expect(lex_person.works).to all(be_work_type_original)
      expect(result.text).to eq('על המחבר:')
      expect(result.name).to eq('p')
    end

    it 'assigns sequential seqno' do
      result
      expect(lex_person.works.map(&:seqno)).to eq([1, 2])
    end

    it 'stops at the next named anchor header' do
      result
      expect(lex_person.works.size).to eq(2)
    end
  end

  context 'when works list is wrapped in a span and has no following elements' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריה:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר ראשון (תל אביב : דביר, 1990)</li>
            <li>ספר שני (ירושלים : כתר, 2000)</li>
            <li>ספר שלישי (תל אביב : עם עובד, 2005)</li>
          </ul>
        </span>
      HTML
    end

    it 'extracts works from inside the span and returns nil' do
      expect(lex_person.works.size).to eq(3)
      expect(lex_person.works).to all(be_work_type_original)
      expect(result).to be_nil
    end
  end

  context 'when person has multiple work types' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי ראשון (תל אביב : דביר, 1990)</li>
            <li>ספר מקורי שני (ירושלים : כתר, 2000)</li>
          </ul>
          <p><font>תרגום:</font></p>
          <ul>
            <li>ספר מתורגם (תל אביב : הוצאה, 2010)</li>
          </ul>
          <p><font>עריכה:</font></p>
          <ul>
            <li>ספר נערך ראשון (תל אביב : הוצאה, 2005)</li>
            <li>ספר נערך שני (ירושלים : הוצאה, 2008)</li>
          </ul>
        </span>
        <p><a name="Bib.">על המחבר:</a></p>
      HTML
    end

    it 'extracts works and assigns seqno independetly for each work_type' do
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
      expect(lex_person.works.select(&:work_type_translated?).size).to eq(1)
      expect(lex_person.works.select(&:work_type_edited?).size).to eq(2)

      expect(lex_person.works.select(&:work_type_original?).map(&:seqno)).to eq([1, 2])
      expect(lex_person.works.select(&:work_type_translated?).map(&:seqno)).to eq([1])
      expect(lex_person.works.select(&:work_type_edited?).map(&:seqno)).to eq([1, 2])

      expect(result).to be_nil
    end
  end

  context 'when the translations section is headed תרגומים: (plural)' do
    # Mirrors 00156.php, where the plural header was not recognized and all works
    # were classified as original, so the pane showed no original/translation split.
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי (תל אביב : דביר, 1990)</li>
          </ul>
          <p><font size="4" color="#0000FF">תרגומים:</font></p>
          <ul>
            <li>חמור הזהב / לוקיוס אפוליאוס (תל־אביב : ישראל, 1954)</li>
            <li>מבחר הסיפור הסיני / לין יו־טאנג (תל־אביב : הדר, 1954)</li>
          </ul>
        </span>
      HTML
    end

    it 'classifies the works under it as translated' do
      expect(lex_person.works.select(&:work_type_original?).size).to eq(1)
      expect(lex_person.works.select(&:work_type_translated?).map(&:title))
        .to contain_exactly('חמור הזהב / לוקיוס אפוליאוס', 'מבחר הסיפור הסיני / לין יו־טאנג')
    end
  end

  context 'when the translations section is headed תרגומיו:' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי (תל אביב : דביר, 1990)</li>
          </ul>
          <p><font>תרגומיו:</font></p>
          <ul>
            <li>ספר מתורגם (תל אביב : הוצאה, 2010)</li>
          </ul>
        </span>
      HTML
    end

    it 'classifies the works under it as translated' do
      expect(lex_person.works.select(&:work_type_translated?).size).to eq(1)
    end
  end

  context 'when a section lists translations of the person’s works into foreign languages' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי (תל אביב : דביר, 1990)</li>
          </ul>
          <p><font>תרגומים לשפות זרות:</font></p>
          <ul>
            <li>His book / translated by Someone (London : Publisher, 1995)</li>
          </ul>
        </span>
      HTML
    end

    it 'keeps them as original works, since the person did not translate them' do
      expect(lex_person.works.select(&:work_type_translated?)).to be_empty
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
    end
  end

  context 'when works list includes a festschrift section' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי (תל אביב : דביר, 1990)</li>
          </ul>
          <font size="4" color="#0000FF">ספר זכרון:</font>
          <ul>
            <li>ספר יובל לפלוני (ירושלים : מוסד ביאליק, 2000)</li>
          </ul>
          <font color="#FF0000">ספרי יובל וזכרון</font>
          <ul>
            <li>ספר יובל לאלמוני (תל אביב : הוצאה, 2005)</li>
          </ul>
        </span>
      HTML
    end

    it 'classifies works under ספר זכרון: and ספרי יובל וזכרון as festschrift' do
      expect(lex_person.works.select(&:work_type_original?).size).to eq(1)
      expect(lex_person.works.select(&:work_type_festschrift?).size).to eq(2)
      expect(lex_person.works.select(&:work_type_festschrift?).map(&:seqno)).to eq([1, 2])
    end
  end

  context 'when all content is inside a span embedded within the works header paragraph' do
    # Mirrors the structure produced by Nokogiri for files like 00032.php where the raw PHP has
    # <span dir="rtl"> before <body>, so the parser nests everything inside that span, which itself
    # ends up as a child of the <p><a name="Books"> element.
    let(:html) do
      <<~HTML
        <p><font><a name="Books">ספריו:</a></font><span dir="rtl">
          <ul>
            <li>ספר ראשון (תל אביב : דביר, 1990)</li>
            <li>ספר שני (ירושלים : כתר, 2000)</li>
          </ul>
          <p><font>עריכה:</font><font><a href="list.pdf">רשימה מפורטת</a></font></p>
          <ul>
            <li>ספר נערך (תל אביב : הוצאה, 2005)</li>
          </ul>
          <font><a name="Bib.">על המחבר:</a></font>
        </span></p>
      HTML
    end

    it 'extracts original works from the embedded span' do
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
    end

    it 'recognizes the edited section header even when paragraph contains extra content' do
      expect(lex_person.works.select(&:work_type_edited?).size).to eq(1)
    end

    it 'stops at the citations header and returns it' do
      expect(result).to be_present
      expect(result.at_css('a[name="Bib."]')).to be_present
    end
  end

  context 'when a work-type sub-header carries a duplicate of the Books anchor' do
    # Mirrors 00104.php, where the 'תרגומיה:' sub-header was built by copying the works header's
    # markup, anchor and all, and an unclosed <span dir="rtl"> was re-opened before its list --
    # so Nokogiri nests the translations one level deeper than the originals. The walk used to
    # stop at the duplicate anchor, losing all twelve translations.
    let(:html) do
      <<~HTML
        <font size="4" color="#0000FF">ספריה<a name="Books">:</a></font>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי (תל אביב : דביר, 1990)</li>
          </ul>
          <font size="4" color="#0000FF">תרגומיה<a name="Books">:</a></font>
          <span dir="rtl">
            <ul>
              <li>הכומר מטור / אונורה דה בלזאק (ירושלים : כרמל, 1999)</li>
              <li>נואה נואה : מסע לטהיטי / פול גוגן (רמת השרון : אסיה, 2007)</li>
            </ul>
            <font size="4" color="#0000FF"><a name="Bib.">על המחברת ויצירתה:</a></font>
      HTML
    end

    it 'keeps parsing past the duplicate anchor and classifies the works as translated' do
      expect(lex_person.works.select(&:work_type_original?).map(&:title)).to eq(['ספר מקורי'])
      expect(lex_person.works.select(&:work_type_translated?).map(&:title))
        .to eq(['הכומר מטור / אונורה דה בלזאק', 'נואה נואה : מסע לטהיטי / פול גוגן'])
    end

    it 'still stops at the citations header' do
      expect(result.at_css('a[name="Bib."]')).to be_present
    end
  end

  context 'when a work-type header is hard-wrapped across two source lines' do
    # Mirrors 01741.php: the newline inside the header text hid it from WORK_TYPE_HEADERS,
    # so all 43 translations below it were filed as original works.
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <ul>
          <li>ספר מקורי (תל אביב : דביר, 1990)</li>
        </ul>
        <p>ספרים \r
        בתרגומו:</p>
        <ul>
          <li>ספר מתורגם (תל אביב : הוצאה, 2010)</li>
        </ul>
      HTML
    end

    it 'recognizes the header despite the embedded newline' do
      expect(lex_person.works.select(&:work_type_translated?).map(&:title)).to eq(['ספר מתורגם'])
    end
  end

  context 'when citations header appears inside the works span (malformed)' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריה:</a></p>
        <span dir="rtl">
          <ul>
            <li>ספר מקורי ראשון (תל אביב : דביר, 1990)</li>
            <li>ספר מקורי שני (ירושלים : כתר, 2000)</li>
          </ul>
          <p><font>כתיבה, עריכה ושכתוב:</font></p>
          <ul>
            <li>ספר נערך (תל אביב : הוצאה, 2005)</li>
          </ul>
          <p><font><a name="Bib.">על המחברת ויצירתה:</a></font></p>
        </span>
      HTML
    end

    it 'stops parsing at the citations header and returns it as result' do
      expect(lex_person.works.size).to eq(3)
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
      expect(lex_person.works.select(&:work_type_edited?).size).to eq(1)
      expect(result.text).to eq('על המחברת ויצירתה:')
      expect(result.name).to eq('p')
    end
  end

  context 'when a works section is split under sub-headings written as bare text' do
    # Mirrors 00421.php: 'שירה ופרוזה:' and 'עיון:' sit as text nodes between the lists, so a walk
    # over elements alone never saw them and the two groups were merged into one flat list.
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריה:</a></p>
        שירה ופרוזה:
        <ul>
          <li>לולא היה עלי למהר (תל־אביב : מי לי, 1971)</li>
          <li>רק הירוק : שירים (תל־אביב : הקיבוץ המאוחד, תשמ״א)</li>
        </ul>
        עיון:
        <ul>
          <li>מבוא לספרות הדקאדנס באירופה (תל־אביב : משרד הביטחון, 1994)</li>
        </ul>
        <font size="4" color="#0000FF">תרגום:</font>
        <ul>
          <li>מזמורים ישנים / אולגה סדקובה (ירושלים : כרמל, 1997)</li>
        </ul>
        <p><a name="Bib.">על המחברת ויצירתה:</a></p>
      HTML
    end

    it 'puts the works under each sub-heading of the original works' do
      expect(lex_person.work_groups.map { |g| [g.work_type, g.title] })
        .to eq([['original', 'שירה ופרוזה'], %w(original עיון)])

      poetry, research = lex_person.work_groups.to_a
      expect(lex_person.works.select { |w| w.work_group.equal?(poetry) }.map(&:title))
        .to eq(['לולא היה עלי למהר', 'רק הירוק : שירים'])
      expect(lex_person.works.select { |w| w.work_group.equal?(research) }.map(&:title))
        .to eq(['מבוא לספרות הדקאדנס באירופה'])
      expect(lex_person.works.select(&:work_type_original?).map(&:seqno)).to eq([1, 2, 3])
    end

    it 'ends the sub-heading at the next work-type header' do
      translated = lex_person.works.select(&:work_type_translated?)
      expect(translated.map(&:title)).to eq(['מזמורים ישנים / אולגה סדקובה'])
      expect(translated.map(&:work_group)).to eq([nil])
    end

    it 'saves the sub-headings along with the person' do
      lex_person.save!
      expect(LexPersonWorkGroup.where(lex_person_id: lex_person.id).ordered.pluck(:title, :seqno))
        .to eq([['שירה ופרוזה', 1], ['עיון', 2]])
      expect(lex_person.reload.works_sections.first.groups.map { |g, works| [g.title, works.size] })
        .to eq([['שירה ופרוזה', 2], ['עיון', 1]])
    end
  end

  context 'when an unrecognized header follows a work-type section' do
    # Mirrors 01661.php's 'עריכת תרגום - ספרי עיון:' and the more common 'מבחר ממאמריו:' after a
    # translations section. Most such headers open a section of original works, so that is where
    # the sub-heading goes -- they used to reset the works to original too, just without a heading.
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <ul>
          <li>ספר מקורי (תל אביב : דביר, 1990)</li>
        </ul>
        <p><font>עריכה:</font></p>
        <ul>
          <li>ספר נערך (תל אביב : הוצאה, 2005)</li>
        </ul>
        <p><font>מבחר ממאמריו:</font></p>
        <ul>
          <li>מאמר ראשון (תל אביב : הוצאה, 2006)</li>
        </ul>
      HTML
    end

    it 'keeps the section before it intact and opens a sub-heading of the original works' do
      expect(lex_person.works.select(&:work_type_edited?).map(&:title)).to eq(['ספר נערך'])
      expect(lex_person.work_groups.map { |g| [g.work_type, g.title] }).to eq([['original', 'מבחר ממאמריו']])
      expect(lex_person.works.last.work_group).to eq(lex_person.work_groups.first)
      expect(lex_person.works.last.seqno).to eq(2)
    end
  end

  context 'when header markup carries debris rather than a sub-heading' do
    # A work-type header split across elements (<font>עריכה</font><font>(מבחר)</font><font>:</font>,
    # as in 00036.php), comment fragments (02730.php), a last-updated footer, and bare text that is a
    # piece of a broken list item (00424.php).
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <ul>
          <li>ספר מקורי (תל אביב : דביר, 1990)</li>
        </ul>
        <font>עריכה</font><font>(מבחר)</font><font>:</font>
        <ul>
          <li>ספר נערך (תל אביב : הוצאה, 2005)</li>
        </ul>
        <font>&lt;</font><font>הרשימה באדיבות יעל שכנאי&gt;</font>
        עברית והולנדית – עמוד מול עמוד
        <ul>
          <li>ספר נערך שני (תל אביב : הוצאה, 2008)</li>
        </ul>
        <font>עודכן לאחרונה: 25 באפריל 2017</font>
      HTML
    end

    it 'makes no sub-heading of any of it and keeps the works in their section' do
      expect(lex_person.work_groups).to be_empty
      expect(lex_person.works.map { |w| [w.work_type, w.title] })
        .to eq([['original', 'ספר מקורי'], ['edited', 'ספר נערך'], ['edited', 'ספר נערך שני']])
    end
  end

  context 'when a sub-heading has no works under it' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <ul>
          <li>ספר מקורי (תל אביב : דביר, 1990)</li>
        </ul>
        <p><font>ספרים נוספים:</font></p>
        <p><font>מחזות:</font></p>
        <ul>
          <li>מחזה (תל אביב : הוצאה, 2005)</li>
        </ul>
        <p><font>מקורות: ארכיון קיבוץ כפר־בלום.</font></p>
      HTML
    end

    it 'does not create it' do
      expect(lex_person.work_groups.map(&:title)).to eq(['מחזות'])
    end
  end

  context 'when a sub-heading is repeated within a section' do
    let(:html) do
      <<~HTML
        <p><a name="Books">ספריו:</a></p>
        <p><font>מחזות:</font></p>
        <ul>
          <li>מחזה ראשון (תל אביב : הוצאה, 2005)</li>
        </ul>
        <p><font>מחזות:</font></p>
        <ul>
          <li>מחזה שני (תל אביב : הוצאה, 2006)</li>
        </ul>
      HTML
    end

    it 'puts the works of both under a single sub-heading' do
      expect(lex_person.work_groups.size).to eq(1)
      expect(lex_person.works.map(&:work_group).uniq).to eq(lex_person.work_groups.to_a)
    end
  end
end
