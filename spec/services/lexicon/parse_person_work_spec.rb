# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ParsePersonWork do
  subject(:result) { described_class.call(list_item) }

  let(:list_item) { Nokogiri::HTML::DocumentFragment.parse("<li>#{line}</li>").at_css('li') }

  context 'when work string without comment is provided' do
    let(:line) { 'רוני צרצר לומד לעבוד (תל אביב : מ. ניומן, תשי"ג 1953)' }

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'רוני צרצר לומד לעבוד',
        publisher: 'מ. ניומן',
        publication_place: 'תל אביב',
        publication_date: 'תשי"ג 1953',
        comment: nil
      )
    end
  end

  context 'when work string with comment is provided' do
    # rubocop:disable Layout/LineLength
    let(:line) { 'וידויי ההרפתקן פליכס קרול : זכרונות, חלק ראשון / תומאס מאן (מרחביה : ספרית פועלים, 1956) <מהדורה מתוקנת יצאה לאור בתש״ם 1980>' }
    # rubocop:enable Layout/LineLength

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'וידויי ההרפתקן פליכס קרול : זכרונות, חלק ראשון / תומאס מאן',
        publisher: 'ספרית פועלים',
        publication_place: 'מרחביה',
        publication_date: '1956',
        comment: 'מהדורה מתוקנת יצאה לאור בתש״ם 1980'
      )
    end
  end

  context 'when hebrew year is specified' do
    let(:line) { 'באזקים : שירי מרדכי אבי־שאול (תל־אביב : כתובים, תרצ״ב) ' }

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'באזקים : שירי מרדכי אבי־שאול',
        publisher: 'כתובים',
        publication_place: 'תל־אביב',
        publication_date: 'תרצ״ב',
        comment: nil
      )
    end
  end

  context 'when line contains more than one colon and contains linebreaks' do
    let(:line) do
      <<~HTML
        קום קרא (חבל מודיעין : דביר : הקשרים – המכון לחקר הספרות והתרבות היהודית
          והישראלית, 2017)
      HTML
    end

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'קום קרא',
        publisher: 'דביר : הקשרים – המכון לחקר הספרות והתרבות היהודית והישראלית',
        publication_place: 'חבל מודיעין',
        publication_date: '2017',
        comment: nil
      )
    end
  end

  context 'when several comments with links are provided' do
    let(:line) do
      <<~HTML
        <a href="00397004.php">פולחן הסופר ודת המדינה</a> (אור־יהודה : דביר, תשע״א
          2011) <font size="2">&lt;עריכה – <a href="/lex/entries/#{editor_entry.id}">הילה בלום</a>&gt; &lt;על
          <a href="00397.php">עמוס עוז</a>&gt;</font><br>
          <font size="2"><a href="00397004.php">תוכן העניינים</a></font>
      HTML
    end

    # We create a lex_entry only for one linked person (for editor)
    let!(:editor_entry) { create(:lex_file, :person, title: 'הילה בלום', fname: '02228.php').lex_entry }

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'פולחן הסופר ודת המדינה',
        publisher: 'דביר',
        publication_place: 'אור־יהודה',
        publication_date: 'תשע״א 2011',
        comment: nil
      )

      expect(result.linked_people.size).to eq(2)
      expect(result.linked_people[0]).to have_attributes(
        name: 'הילה בלום',
        link_type: 'editor',
        person_entry: editor_entry,
        seqno: 1
      )
      expect(result.linked_people[1]).to have_attributes(
        name: 'עמוס עוז',
        link_type: 'about',
        person_entry: nil,
        seqno: 2
      )
    end
  end

  context 'when complex comment with several coauthors present' do
    let(:line) do
      <<~HTML
        ממה באמת עשוי הירח&nbsp; (אור יהודה : כנרת, תש״ע 2010) <font size="2">
          &lt;בשיתוף זהר שוורץ ; איורים – רחלי שלו ; עריכה – יעל גובר&gt;</font>
      HTML
    end

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'ממה באמת עשוי הירח',
        publisher: 'כנרת',
        publication_place: 'אור יהודה',
        publication_date: 'תש״ע 2010',
        comment: nil
      )

      expect(result.linked_people.size).to eq(3)
      expect(result.linked_people[0]).to have_attributes(
        name: 'זהר שוורץ',
        link_type: 'collaborator',
        person_entry: nil,
        seqno: 1
      )
      expect(result.linked_people[1]).to have_attributes(
        name: 'רחלי שלו',
        link_type: 'illustrator',
        person_entry: nil,
        seqno: 2
      )
      expect(result.linked_people[2]).to have_attributes(
        name: 'יעל גובר',
        link_type: 'editor',
        person_entry: nil,
        seqno: 3
      )
    end
  end

  context 'when coauthor comment is separated by commas' do
    let(:line) do
      <<~HTML
        הלב הקבור (תל־אביב : אחוזת בית, תשס״ו 2006) <font size="2">&lt;עריכה, שרי גוטמן&gt;</font>
      HTML
    end

    it 'parses work successfully' do
      expect(result).to have_attributes(
        title: 'הלב הקבור',
        publisher: 'אחוזת בית',
        publication_place: 'תל־אביב',
        publication_date: 'תשס״ו 2006',
        comment: nil
      )

      expect(result.linked_people.size).to eq(1)

      expect(result.linked_people[0]).to have_attributes(
        name: 'שרי גוטמן',
        link_type: 'editor',
        person_entry: nil,
        seqno: 1
      )
    end
  end

  context 'when the title contains a link to a person LexEntry' do
    let!(:person_entry) { create(:lex_file, :person, title: 'אפרת דנון').lex_entry }
    let(:line) do
      "ספר זכרון: <a href=\"/lex/entries/#{person_entry.id}\">אפרת דנון</a> (ירושלים : מוסד ביאליק, 1995)"
    end

    it 'extracts the title without HTML tags' do
      expect(result.title).to eq('ספר זכרון: אפרת דנון')
    end

    it 'stores the title link with text and entry_id' do
      expect(result.title_links).to eq([{ 'text' => 'אפרת דנון', 'entry_id' => person_entry.id }])
    end
  end

  context 'when a comment contains a person link but the title does not' do
    let!(:editor_entry) { create(:lex_file, :person, title: 'יעל גובר').lex_entry }
    let(:line) do
      "ילדים מהנים (תל-אביב : הקיבוץ, 2010) <font size=\"2\">&lt;עריכה – " \
        "<a href=\"/lex/entries/#{editor_entry.id}\">יעל גובר</a>&gt;</font>"
    end

    it 'does not add title_links for comment-only person links' do
      expect(result.title_links).to be_nil
    end

    it 'adds the person as a linked_person instead' do
      expect(result.linked_people.size).to eq(1)
      expect(result.linked_people[0]).to have_attributes(name: 'יעל גובר', link_type: 'editor')
    end
  end

  context 'when there are no links anywhere' do
    let(:line) { 'ספרי שירה (תל-אביב : שוקן, 2005)' }

    it 'returns nil for title_links' do
      expect(result.title_links).to be_nil
    end
  end
end
