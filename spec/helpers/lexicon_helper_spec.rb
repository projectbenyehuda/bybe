# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LexiconHelper, type: :helper do
  describe '#bio_for_display' do
    let(:lex_entry) { instance_double(LexEntry) }
    let(:filename) { instance_double(ActiveStorage::Filename, to_s: 'portrait.jpg') }
    let(:blob) { instance_double(ActiveStorage::Blob, filename: filename) }

    context 'when no profile image is set' do
      before { allow(lex_entry).to receive(:profile_image).and_return(nil) }

      it 'returns bio text unchanged' do
        bio = 'Some bio text <img src="portrait.jpg">'
        expect(helper.bio_for_display(bio, lex_entry)).to eq(bio)
      end
    end

    context 'when bio is blank' do
      before { allow(lex_entry).to receive(:profile_image).and_return(blob) }

      it 'returns nil unchanged' do
        expect(helper.bio_for_display(nil, lex_entry)).to be_nil
      end

      it 'returns empty string unchanged' do
        expect(helper.bio_for_display('', lex_entry)).to eq('')
      end
    end

    context 'when profile image is set' do
      before { allow(lex_entry).to receive(:profile_image).and_return(blob) }

      it 'removes an img tag whose src matches the profile image filename' do
        bio = 'Intro text <img src="portrait.jpg"> more text'
        result = helper.bio_for_display(bio, lex_entry)
        expect(result).to eq('Intro text  more text')
        expect(result).not_to include('<img')
      end

      it 'removes a self-closing img tag' do
        bio = '<img src="portrait.jpg" />'
        expect(helper.bio_for_display(bio, lex_entry)).not_to include('<img')
      end

      it 'removes an img tag with other attributes before src' do
        bio = '<img alt="Author photo" src="portrait.jpg" class="photo">'
        expect(helper.bio_for_display(bio, lex_entry)).not_to include('<img')
      end

      it 'removes an img tag when src contains a path prefix' do
        bio = '<img src="/uploads/2023/portrait.jpg">'
        expect(helper.bio_for_display(bio, lex_entry)).not_to include('<img')
      end

      it 'removes an img tag with single-quoted src' do
        bio = "<img src='portrait.jpg'>"
        expect(helper.bio_for_display(bio, lex_entry)).not_to include('<img')
      end

      it 'preserves img tags whose src does not match the profile image' do
        bio = 'Text <img src="other-image.jpg"> more'
        result = helper.bio_for_display(bio, lex_entry)
        expect(result).to include('<img src="other-image.jpg">')
      end

      it 'returns bio text unchanged when it contains no img tags' do
        bio = 'Just plain text biography'
        expect(helper.bio_for_display(bio, lex_entry)).to eq(bio)
      end
    end
  end

  describe '#render_external_identifiers' do
    it 'returns nil when external_identifiers is blank' do
      expect(helper.render_external_identifiers(nil)).to be_nil
      expect(helper.render_external_identifiers({})).to be_nil
    end

    it 'renders LC identifier with correct URL' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164' })
      expect(result).to include('LC –')
      expect(result).to include('https://id.loc.gov/authorities/n79021164')
      expect(result).to include('n79021164')
    end

    it 'renders VIAF identifier with correct URL' do
      result = helper.render_external_identifiers({ 'viaf' => '36924286' })
      expect(result).to include('VIAF –')
      expect(result).to include('https://viaf.org/viaf/36924286')
    end

    it 'renders NLI identifier with correct URL' do
      result = helper.render_external_identifiers({ 'nli' => '000123456' })
      expect(result).to include('NLI –')
      expect(result).to include('https://www.nli.org.il/he/authorities/000123456')
    end

    it 'renders Wikidata identifier with correct URL' do
      result = helper.render_external_identifiers({ 'wikidata' => 'Q12345' })
      expect(result).to include('Wikidata –')
      expect(result).to include('https://www.wikidata.org/wiki/Q12345')
    end

    it 'renders OpenLibrary identifier with correct URL' do
      result = helper.render_external_identifiers({ 'openlibrary' => 'OL1234567A' })
      expect(result).to include('OpenLibrary –')
      expect(result).to include('https://openlibrary.org/authors/OL1234567A')
    end

    it 'skips unknown identifier keys like j9u' do
      result = helper.render_external_identifiers({ 'j9u' => '987654321' })
      expect(result).to be_nil
    end

    it 'joins multiple identifiers with vertical pipes' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164', 'viaf' => '36924286' })
      expect(result).to include(' | ')
      expect(result).to include('LC –')
      expect(result).to include('VIAF –')
    end

    it 'returns nil when all keys are unknown' do
      result = helper.render_external_identifiers({ 'j9u' => '123', 'unknown' => '456' })
      expect(result).to be_nil
    end

    it 'renders links opening in a new tab' do
      result = helper.render_external_identifiers({ 'lc' => 'n79021164' })
      expect(result).to include('target="_blank"')
      expect(result).to include('rel="noopener noreferrer"')
    end
  end

  describe '#render_person_work_title' do
    let(:work) { build(:lex_person_work, title: 'ספר זכרון לאפרת דנון', title_links: nil) }

    context 'when no lex_publication and no title_links' do
      it 'returns the plain title string' do
        expect(helper.render_person_work_title(work)).to eq('ספר זכרון לאפרת דנון')
      end
    end

    context 'when title_links are present' do
      let!(:target_entry) { create(:lex_entry, :person, title: 'אפרת דנון') }

      before do
        work.title_links = [{ 'text' => 'אפרת דנון', 'entry_id' => target_entry.id }]
      end

      it 'replaces the linked text with an anchor tag' do
        result = helper.render_person_work_title(work)
        expect(result).to include('<a ')
        expect(result).to include('אפרת דנון')
        expect(result).to include(lexicon_entry_path(target_entry))
      end

      it 'preserves surrounding title text' do
        result = helper.render_person_work_title(work)
        expect(result).to include('ספר זכרון ל')
      end
    end

    context 'when lex_publication is present' do
      let!(:publication_entry) { create(:lex_entry, :publication, title: 'כותרת הפרסום') }

      before { work.lex_publication = publication_entry.lex_item }

      it 'links the title to the publication entry regardless of title_links' do
        work.title_links = [{ 'text' => 'אפרת דנון', 'entry_id' => 999 }]
        result = helper.render_person_work_title(work)
        expect(result).to include(lexicon_entry_path(publication_entry))
        expect(result).to include('כותרת הפרסום')
      end
    end

    context 'when a collection is present' do
      let(:collection) { create(:collection, title: 'כרך מקוון') }

      before { work.collection = collection }

      it 'links the work title to the collection' do
        result = helper.render_person_work_title(work)
        expect(result).to include(collection_path(collection))
        expect(result).to include('ספר זכרון לאפרת דנון')
      end

      it 'takes precedence over title_links' do
        work.title_links = [{ 'text' => 'אפרת דנון', 'entry_id' => 999 }]
        result = helper.render_person_work_title(work)
        expect(result).to include(collection_path(collection))
        expect(Nokogiri::HTML.fragment(result).css('a').size).to eq(1)
      end

      it 'takes precedence over lex_publication' do
        work.lex_publication = create(:lex_entry, :publication, title: 'כותרת הפרסום').lex_item
        result = helper.render_person_work_title(work)
        expect(result).to include(collection_path(collection))
        expect(result).not_to include('כותרת הפרסום')
      end
    end
  end

  describe '#render_person_work' do
    let(:work) do
      create(:lex_person_work, title: 'ספר הזכרונות', publication_place: 'תל אביב', publisher: 'עם עובד',
                               publication_date: '1975', title_links: nil)
    end

    # the rendered text minus the markup, which is what the spacing rule is about
    def rendered_text(work)
      Nokogiri::HTML.fragment(helper.render_person_work(work)).text
    end

    it 'puts no space inside the angled brackets, and one space around them' do
      create(:lex_linked_person, person_work: work, name: 'דן פגיס', link_type: :editor, person_entry: nil)
      work.update!(comment: 'כולל אחרית דבר')

      expect(rendered_text(work.reload))
        .to eq('ספר הזכרונות (תל אביב : עם עובד, 1975) <עריכה דן פגיס> <כולל אחרית דבר>')
    end

    it 'strips whitespace surrounding the content of the brackets' do
      work.update!(comment: "  כולל אחרית דבר  \n\n  ובו תצלומים  ")

      expect(rendered_text(work.reload))
        .to eq('ספר הזכרונות (תל אביב : עם עובד, 1975) <כולל אחרית דבר> <ובו תצלומים>')
    end

    it 'keeps the brackets outside a link that spans the whole comment' do
      target = create(:lex_entry, :person, title: 'יגאל שוורץ')
      work.update!(comment: 'יגאל שוורץ', comment_links: [{ 'text' => 'יגאל שוורץ', 'entry_id' => target.id }])

      result = helper.render_person_work(work.reload)
      expect(result).to include("&lt;<a href=\"#{lexicon_entry_path(target)}\">יגאל שוורץ</a>&gt;")
      expect(rendered_text(work)).to end_with(') <יגאל שוורץ>')
    end
  end

  describe '#render_person_work_comment' do
    let!(:target_entry) { create(:lex_entry, :person, title: 'יגאל שוורץ') }
    let(:comment) { 'כולל אחרית דבר מאת יגאל שוורץ' }

    context 'when comment_links match a name in the comment' do
      let(:comment_links) { [{ 'text' => 'יגאל שוורץ', 'entry_id' => target_entry.id }] }

      it 'hyperlinks the matched name and keeps the surrounding text' do
        result = helper.render_person_work_comment(comment, comment_links)
        expect(result).to include('<a ')
        expect(result).to include(lexicon_entry_path(target_entry))
        expect(result).to include('כולל אחרית דבר מאת')
      end
    end

    context 'when comment_links is nil' do
      it 'returns the escaped comment unchanged' do
        expect(helper.render_person_work_comment(comment, nil)).to eq(comment)
      end
    end

    context 'when the comment contains HTML-special characters' do
      it 'escapes them' do
        expect(helper.render_person_work_comment('a < b & c', nil)).to eq('a &lt; b &amp; c')
      end
    end

    context 'when the linked entry no longer exists' do
      it 'leaves the name as plain (escaped) text' do
        result = helper.render_person_work_comment(comment, [{ 'text' => 'יגאל שוורץ', 'entry_id' => 999_999 }])
        expect(result).not_to include('<a ')
        expect(result).to include('יגאל שוורץ')
      end
    end
  end

  describe '#apply_text_links' do
    let!(:target_entry) { create(:lex_entry, :publication, title: 'שדות ומזוודות') }

    it 'links text to a lexicon entry of any type' do
      result = helper.apply_text_links('בספרו: שדות ומזוודות : תזות',
                                       [{ 'text' => 'שדות ומזוודות', 'entry_id' => target_entry.id }])
      expect(result).to include(lexicon_entry_path(target_entry))
      expect(result).to include('בספרו:')
    end

    it 'links text to an arbitrary URL, opening it in a new tab' do
      result = helper.apply_text_links('תרגם שמעון בוזגלו', [{ 'text' => 'שמעון בוזגלו',
                                                               'url' => 'http://example.com/x' }])
      expect(result).to include('href="http://example.com/x"')
      expect(result).to include('target="_blank"')
      expect(result).to include('rel="noopener noreferrer"')
    end

    it 'leaves text alone when the pair does not occur in it' do
      result = helper.apply_text_links('a text', [{ 'text' => 'absent', 'url' => 'http://example.com' }])
      expect(result).to eq('a text')
    end

    it 'ignores a pair with a blank target' do
      result = helper.apply_text_links('some text', [{ 'text' => 'some', 'url' => '' }])
      expect(result).to eq('some text')
    end

    it 'escapes the text it is given' do
      expect(helper.apply_text_links('a < b & c', nil)).to eq('a &lt; b &amp; c')
    end
  end

  describe '#citations_subject_header' do
    it 'wraps a plain work title in the "about" template' do
      expect(helper.citations_subject_header('שורשי אויר')).to eq('על ״שורשי אויר״')
    end

    it 'falls back to the general header when there is no subject' do
      expect(helper.citations_subject_header(nil)).to eq('כללי')
    end

    it 'shows a subject already phrased as על "..." as-is' do
      expect(helper.citations_subject_header('על "שורשי אויר"')).to eq('על "שורשי אויר"')
    end

    it 'shows an already-phrased subject with trailing text as-is' do
      expect(helper.citations_subject_header('על "כל השירים" (2009)')).to eq('על "כל השירים" (2009)')
    end

    it 'recognizes Hebrew gershayim as the opening quote' do
      expect(helper.citations_subject_header('על ״שורשי אויר״')).to eq('על ״שורשי אויר״')
    end

    it 'still wraps a work title that merely begins with the word על' do
      expect(helper.citations_subject_header('על חכמות דרכים : שירים')).to eq('על ״על חכמות דרכים : שירים״')
    end
  end

  describe '#grouped_and_ordered_citations' do
    let(:person) { create(:lex_person) }
    let!(:work) { create(:lex_person_work, person: person, title: 'שיחות אינטימיות', seqno: 1) }
    let!(:books) { create(:lex_citation_group, person: person, title: 'ספרים', seqno: 1) }
    let!(:articles) { create(:lex_citation_group, person: person, title: 'מאמרים', seqno: 2) }

    let!(:plain) { create(:lex_citation, person: person, seqno: 1) }
    let!(:book) { create(:lex_citation, person: person, citation_group: books, seqno: 1) }
    let!(:article) { create(:lex_citation, person: person, citation_group: articles, seqno: 1) }
    let!(:about_work) { create(:lex_citation, person: person, person_work: work, seqno: 1) }
    let!(:unresolved) { create(:lex_citation, person: person, subject: 'על ״ספר אחר״', seqno: 1) }

    let(:groups) { helper.grouped_and_ordered_citations(person) }

    it 'orders the general citations first, then the works, then unresolved legacy headings' do
      expect(groups.keys.map(&:kind)).to eq(%i(general heading heading work subject))
      expect(groups.values).to eq([[plain], [book], [article], [about_work], [unresolved]])
    end

    it 'orders the general sub-headings by the editor\'s own order, not alphabetically' do
      articles.update!(seqno: 0)
      expect(helper.grouped_and_ordered_citations(person).keys.filter_map { |h| h.title if h.editable? })
        .to eq(%w(מאמרים ספרים))
    end

    it 'shows a general sub-heading verbatim and a work heading in the "about" template' do
      heading, work_heading = groups.keys.values_at(1, 3)
      expect(helper.citations_heading_text(heading)).to eq('ספרים')
      expect(helper.citations_heading_text(work_heading)).to eq('על ״שיחות אינטימיות״')
    end

    # A person may have both a work and a general sub-heading called 'מאמרים'; keying the groups on
    # the bare title would silently merge their citations into one list.
    it 'keeps a sub-heading and a same-titled work apart' do
      work.update!(title: 'מאמרים')
      keys = helper.grouped_and_ordered_citations(person).keys.select { |h| h.title == 'מאמרים' }
      expect(keys.map(&:kind)).to contain_exactly(:heading, :work)
    end
  end

  describe '#render_citation with text_links' do
    let(:person) { create(:lex_person) }
    let!(:target_entry) { create(:lex_entry, :publication, title: 'שדות ומזוודות') }
    let(:citation) do
      create(:lex_citation,
             person: person,
             title: 'כל העסק מתפרק בכלל',
             from_publication: 'בספרו: שדות ומזוודות : תזות על הדרמה העברית',
             link: nil,
             authors_count: 0,
             text_links: [{ 'text' => 'שדות ומזוודות', 'entry_id' => target_entry.id }])
    end

    it 'hyperlinks the matched text inside from_publication' do
      expect(helper.render_citation(citation)).to include(lexicon_entry_path(target_entry))
    end

    context 'when the citation has its own link' do
      before { citation.update!(link: 'http://example.com/article') }

      it 'still links the whole title and does not nest anchors in it' do
        result = helper.render_citation(citation)
        expect(result).to include('href="http://example.com/article"')
        expect(result.scan('<a ').size).to eq(2) # the title link and the from_publication link
      end
    end
  end

  describe 'attachment/citation association' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }
    let(:pdf_path) { Rails.root.join('spec/fixtures/files/lexicon/attachments/lorem.pdf') }
    let!(:plain_attachment) { attach('plain.pdf') }

    def attach(filename, lex_entry = entry)
      File.open(pdf_path, 'rb') do |io|
        lex_entry.attachments.attach(io: io, filename: filename, content_type: 'application/pdf')
      end
      lex_entry.attachments.reload.detect { |a| a.filename.to_s == filename }
    end

    describe '#citation_attachments' do
      it 'returns the file referenced by the citation backup_url' do
        cited = attach('cited.pdf')
        citation = create(:lex_citation, person: person, link: nil, backup_url: entry.download_path('cited.pdf'))

        expect(helper.citation_attachments(entry, citation).map(&:id)).to eq([cited.id])
      end

      it 'returns the file referenced by the citation link, even with an anchor' do
        cited = attach('linked.pdf')
        citation = create(:lex_citation, person: person, link: "#{entry.download_path('linked.pdf')}#page=3")

        expect(helper.citation_attachments(entry, citation).map(&:id)).to eq([cited.id])
      end

      it 'returns the file whose blob is attached as the citation backup_file' do
        backed_up = attach('backup.pdf')
        citation = create(:lex_citation, person: person, link: nil)
        citation.backup_file.attach(entry.blob_by_filename('backup.pdf'))

        expect(helper.citation_attachments(entry, citation).map(&:id)).to eq([backed_up.id])
      end

      it 'returns an empty array for a citation with no file of its own' do
        citation = create(:lex_citation, person: person, link: nil, backup_url: nil)
        expect(helper.citation_attachments(entry, citation)).to be_empty
      end

      it 'returns a file claimed by both link and backup_url only once' do
        cited = attach('twice.pdf')
        path = entry.download_path('twice.pdf')
        citation = create(:lex_citation, person: person, link: path, backup_url: path)

        expect(helper.citation_attachments(entry, citation).map(&:id)).to eq([cited.id])
      end

      it 'ignores a backup_file blob that is not one of the entry files' do
        other_entry = create(:lex_entry, lex_item: create(:lex_person))
        attach('foreign.pdf', other_entry)
        citation = create(:lex_citation, person: person, link: nil, backup_url: nil)
        citation.backup_file.attach(other_entry.blob_by_filename('foreign.pdf'))

        expect(helper.citation_attachments(entry, citation)).to be_empty
      end

      it 'accepts a prebuilt attachment index' do
        cited = attach('indexed.pdf')
        citation = create(:lex_citation, person: person, link: entry.download_path('indexed.pdf'))
        index = helper.attachment_index(entry)

        expect(helper.citation_attachments(entry, citation, index).map(&:id)).to eq([cited.id])
      end
    end

    describe '#non_citation_attachments' do
      it 'returns attachments not associated with any citation' do
        create(:lex_citation, person: person, link: nil, backup_url: nil)
        expect(helper.non_citation_attachments(entry, person).map(&:id)).to eq([plain_attachment.id])
      end

      it 'excludes attachments referenced by a citation backup_url' do
        cited = attach('cited.pdf')
        create(:lex_citation, person: person, link: nil, backup_url: entry.download_path('cited.pdf'))

        result = helper.non_citation_attachments(entry, person).map(&:id)
        expect(result).to eq([plain_attachment.id])
        expect(result).not_to include(cited.id)
      end

      it 'excludes attachments referenced by a citation link, even with an anchor' do
        cited = attach('linked.pdf')
        create(:lex_citation, person: person, link: "#{entry.download_path('linked.pdf')}#page=3")

        expect(helper.non_citation_attachments(entry, person).map(&:id)).not_to include(cited.id)
      end

      it 'excludes attachments whose blob is attached as a citation backup_file' do
        backed_up = attach('backup.pdf')
        citation = create(:lex_citation, person: person, link: nil)
        citation.backup_file.attach(entry.blob_by_filename('backup.pdf'))

        expect(helper.non_citation_attachments(entry, person).map(&:id)).to eq([plain_attachment.id])
        expect(backed_up.reload).to be_present # the attachment itself is untouched, merely filtered out
      end

      it 'returns an empty array when every attachment belongs to a citation' do
        create(:lex_citation, person: person, link: entry.download_path('plain.pdf'))
        expect(helper.non_citation_attachments(entry, person)).to be_empty
      end

      # guards the cost of the matching: it must stay linear in attachments, not
      # attachments x citations, since download_path is route generation + unescaping
      it 'derives each download_path once, whatever the number of citations' do
        3.times { |i| attach("extra_#{i}.pdf") }
        5.times { create(:lex_citation, person: person, link: nil, backup_url: nil) }
        allow(entry).to receive(:download_path).and_call_original

        helper.non_citation_attachments(entry, person)

        expect(entry).to have_received(:download_path).exactly(4).times # one per attachment
      end
    end
  end
end
