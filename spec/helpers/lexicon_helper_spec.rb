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
      expect(result).to include('http://uli.nli.org.il/authorities/000123456')
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

  describe 'attachment/citation association' do
    let(:person) { create(:lex_person) }
    let(:entry) { create(:lex_entry, lex_item: person) }
    let(:pdf_path) { Rails.root.join('spec/fixtures/files/lexicon/attachments/lorem.pdf') }
    let!(:plain_attachment) { attach('plain.pdf') }

    def attach(filename)
      entry.attachments.attach(io: File.open(pdf_path, 'rb'), filename: filename, content_type: 'application/pdf')
      entry.attachments.reload.detect { |a| a.filename.to_s == filename }
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
    end
  end
end
