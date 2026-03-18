# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ExtractPersonWorks do
  subject(:result) { described_class.call(works_header, lex_person) }

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

    it 'extracts all original works' do
      result
      expect(lex_person.works.size).to eq(2)
      expect(lex_person.works).to all(be_work_type_original)
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

  context 'when works list is wrapped in a span' do
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

    it 'extracts works from inside the span' do
      result
      expect(lex_person.works.size).to eq(3)
      expect(lex_person.works).to all(be_work_type_original)
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

    it 'extracts original works' do
      result
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
    end

    it 'extracts translated works' do
      result
      expect(lex_person.works.select(&:work_type_translated?).size).to eq(1)
    end

    it 'extracts edited works' do
      result
      expect(lex_person.works.select(&:work_type_edited?).size).to eq(2)
    end

    it 'assigns seqno independently per work type' do
      result
      expect(lex_person.works.select(&:work_type_original?).map(&:seqno)).to eq([1, 2])
      expect(lex_person.works.select(&:work_type_translated?).map(&:seqno)).to eq([1])
      expect(lex_person.works.select(&:work_type_edited?).map(&:seqno)).to eq([1, 2])
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

    it 'stops parsing at the citations header' do
      result
      expect(lex_person.works.size).to eq(3)
    end

    it 'extracts original works before the citations header' do
      result
      expect(lex_person.works.select(&:work_type_original?).size).to eq(2)
    end

    it 'extracts edited works before the citations header' do
      result
      expect(lex_person.works.select(&:work_type_edited?).size).to eq(1)
    end
  end
end
