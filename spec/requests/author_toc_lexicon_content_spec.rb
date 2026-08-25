# frozen_string_literal: true

require 'rails_helper'

# The lexicon section of the Authority TOC shows the same cards as LexEntry#show; only the
# navbar, the sidebar and the preceding Authority TOC itself differ between the two views.
RSpec.describe 'Authority TOC lexicon content', type: :request do
  subject(:call) { get authority_path(author) }

  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:author) { create(:authority, :published, uncollected_works_collection: uncollected_collection) }

  before { author.update(lex_person: lex_entry.lex_item) }

  describe 'authority identifiers card' do
    let(:card_title) { I18n.t('lexicon.entries.show_person.authority_identifiers') }

    context 'when the lexicon entry has external identifiers' do
      let(:lex_entry) do
        create(:lex_entry, :person, status: 'published',
                                    external_identifiers: { 'viaf' => '36924286', 'lc' => 'n79021164' })
      end

      it 'shows the identifiers card, as LexEntry#show does' do
        call
        expect(response.body).to include('lexicon-authority-control')
        expect(response.body).to include(card_title)
        expect(response.body).to include('https://viaf.org/viaf/36924286')
        expect(response.body).to include('https://id.loc.gov/authorities/n79021164')
      end
    end

    context 'when the lexicon entry has no external identifiers' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', external_identifiers: nil) }

      it 'omits the card' do
        call
        expect(response.body).not_to include('lexicon-authority-control')
      end
    end

    context 'when the lexicon entry is not published' do
      let(:lex_entry) do
        create(:lex_entry, :person, status: 'draft', external_identifiers: { 'viaf' => '36924286' })
      end

      it 'shows no lexicon content at all, and so no card' do
        call
        expect(response.body).not_to include('lexicon-authority-control')
      end
    end
  end

  describe 'biography card' do
    let(:lex_person) { create(:lex_person, bio: 'פתיחה <img src="portrait.jpg"> המשך הביוגרפיה') }
    let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: lex_person) }

    before do
      lex_entry.attachments.attach(io: StringIO.new('fake image data'), filename: 'portrait.jpg',
                                   content_type: 'image/jpeg')
      lex_entry.update!(profile_image_id: lex_entry.attachments.first.id)
      author.update(lex_person: lex_person)
    end

    # Deliberately NOT bio_for_display, unlike LexEntry#show: that view renders the portrait
    # separately in .lexicon-author-details and strips the inline copy, while this view has no
    # such block, so the inline <img> is the only copy there is.
    it 'keeps the portrait inline in the bio' do
      call
      expect(response.body).to include('המשך הביוגרפיה')
      expect(response.body).to include('src="portrait.jpg"')
    end
  end

  describe 'last updated line' do
    context 'when the legacy PHP file carried a manual update date' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', date_of_manual_update: '12 ביולי 2023') }

      it 'shows the ingested date, as LexEntry#show does' do
        call
        expect(response.body).to include('lexicon-last-updated')
        expect(response.body).to include('12 ביולי 2023')
      end
    end

    context 'when the legacy PHP file carried no manual update date' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', date_of_manual_update: nil) }

      it 'omits the line' do
        call
        expect(response.body).not_to include('lexicon-last-updated')
      end
    end
  end

  # Reported against benyehuda.org/author/2360 vs. /lex/entries/64: every citation was present on
  # the TOC, but the sub-section headings of the work-attached ones were not. Grouping by the bare
  # `subject` column collapsed all three of them into a single empty <h4> (LexCitation validates
  # `subject` absent whenever `person_work` is set), and the remaining legacy subjects were shown
  # raw, without the 'על ״...״' wrapper the entry page gives them.
  describe 'citation sub-section headings' do
    let(:lex_person) { create(:lex_person) }
    let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: lex_person) }
    let(:work_titles) { ['נערת גומי לעוסה', 'חיים כמעט מתוקים', 'פגומות'] }
    let(:raw_subjects) { ['הנה 6, קונטרס לשירה', 'מעבר לקוני ויליס'] }

    def about_headings(body)
      Nokogiri::HTML(body).css('#lexicon-about h4').map { |node| node.text.strip }
    end

    before do
      work_titles.each_with_index do |title, index|
        work = create(:lex_person_work, person: lex_person, title: title, seqno: index + 1)
        create(:lex_citation, person: lex_person, person_work: work)
      end
      raw_subjects.each { |subject| create(:lex_citation, person: lex_person, subject: subject) }
    end

    it 'headlines every sub-section exactly as the entry page does' do
      call
      toc_headings = about_headings(response.body)

      get lexicon_entry_path(lex_entry)
      entry_headings = about_headings(response.body)

      expect(toc_headings).to eq(entry_headings)
      expect(toc_headings).to eq((work_titles + raw_subjects).map do |subject|
        I18n.t('lexicon.citations.header.subject_line', subject: subject)
      end)
    end
  end

  describe 'empty sections' do
    context 'when the entry has no works, citations, links or identifiers' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published') }

      it 'omits those cards and their navbar lines, keeping the biography' do
        call
        expect(response.body).to include('id="lexicon-biography"')
        expect(response.body).not_to include('id="lexicon-works"')
        expect(response.body).not_to include('id="lexicon-about"')
        expect(response.body).not_to include('id="lexicon-links"')
        expect(response.body).not_to include('data-scroll-target="#lexicon-works"')
        expect(response.body).not_to include('data-scroll-target="#lexicon-about"')
        expect(response.body).not_to include('data-scroll-target="#lexicon-links"')
      end
    end

    context 'when every lexicon section is empty' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: create(:lex_person, bio: nil)) }

      # asserted on the wrapper classes rather than the heading text: the lexicon's name also
      # appears in the "to the lexicon entry" link at the top of the authority page, which is
      # not part of the lexicon block and stays
      it 'drops the lexicon heading and the whole navbar group' do
        call
        expect(response.body).not_to include('peach2-lexicon')
        expect(response.body).not_to include('lexicon-background-color')
        expect(response.body).not_to include('id="lexicon-bio"')
      end
    end

    context 'when the entry has no biography but has other sections' do
      let(:lex_person) { create(:lex_person, bio: nil) }
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: lex_person) }

      before { create(:lex_person_work, person: lex_person) }

      it 'keeps the group anchor so the navbar still scrolls to the lexicon block' do
        call
        expect(response.body).not_to include('id="lexicon-biography"')
        # the biography LINE is gone (a .truncate div), but the group's own scroll target,
        # on the enclosing .nav-book-group, still resolves
        expect(response.body).not_to include('<div class="truncate" data-scroll-target="#lexicon-bio">')
        expect(response.body).to include('data-scroll-target="#lexicon-bio"')
        expect(response.body).to include('id="lexicon-bio"')
        expect(response.body).to include('id="lexicon-works"')
      end
    end
  end

  describe 'lexicon navbar group' do
    # Asserted on the scroll-target attribute, not the label: in Hebrew the nav label
    # (authority_control_section) and the card title (authority_identifiers) are the same
    # string, so matching on the text alone would be satisfied by the card itself.
    let(:nav_entry) { 'data-scroll-target="#lexicon-authority-control"' }

    context 'when the lexicon entry has external identifiers' do
      let(:lex_entry) do
        create(:lex_entry, :person, status: 'published', external_identifiers: { 'viaf' => '36924286' })
      end

      it 'offers a scroll target for the identifiers card' do
        call
        expect(response.body).to include(nav_entry)
      end
    end

    context 'when the lexicon entry has no external identifiers' do
      let(:lex_entry) { create(:lex_entry, :person, status: 'published', external_identifiers: nil) }

      it 'omits the nav entry' do
        call
        expect(response.body).not_to include(nav_entry)
      end
    end
  end

  describe 'citations card' do
    let(:lex_person) { create(:lex_person) }
    let(:lex_entry) { create(:lex_entry, :person, status: 'published', lex_item: lex_person) }
    let(:person_work) { create(:lex_person_work, person: lex_person, title: 'ספר הזכרונות') }

    before do
      create(:lex_citation, person: lex_person, person_work: person_work, title: 'מאמר על הספר')
      create(:lex_citation, person: lex_person, subject: 'נושא ידני', title: 'מאמר על הנושא')
      author.update(lex_person: lex_person)
    end

    it 'headlines work-attached citations by the work title, as LexEntry#show does' do
      call
      # subject_title falls back to the person_work title; grouping by the bare subject column
      # left these citations under one empty header instead.
      expect(response.body).to include(I18n.t('lexicon.citations.header.subject_line', subject: 'ספר הזכרונות'))
      expect(response.body).to include(I18n.t('lexicon.citations.header.subject_line', subject: 'נושא ידני'))
      expect(response.body).not_to include('<h4></h4>')
    end
  end
end
