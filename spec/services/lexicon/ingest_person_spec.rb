# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::IngestPerson do
  subject(:call) { described_class.call(file) }

  context 'when birthdate only is provided', vcr: { cassette_name: 'lexicon/ingest_person/00002' } do
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Gabriella Avigur',
          fname: '00002.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/00002.php')
        }
      )
    end

    it 'parses file successfully' do
      expect { call }.to change(LexPerson, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      person = entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person).to have_attributes(birthdate: '1946', deathdate: nil)
      expect(person.gender).to eq('female')
      expect(person.citations.count).to eq(53)
      expect(person.citations.select { |c| c.person_work.present? }.size).to eq(45)
      # There is a discrepancy between the book name in file and the citation subject for 3 citations
      expect(person.citations.select { |c| c.subject.present? }.size).to eq(3)

      expect(person.works.count).to eq(19)
      expect(person.works.select(&:work_type_original?).size).to eq(15)
      expect(person.works.select(&:work_type_edited?).size).to eq(4)

      expect(entry.english_title).to eq('Gabriela Avigur-Rotem')

      # External identifiers: J9U value overrides legacy NLI value, stored as nli
      expect(entry.external_identifiers).to include(
        'openlibrary' => 'OL4181279A',
        'wikidata' => 'Q12404844',
        'nli' => '987007258174105171',
        'lc' => 'n82204318',
        'viaf' => '22255259'
      )
      expect(entry.external_identifiers).not_to have_key('j9u')
    end
  end

  context 'when only a J9U identifier is present (no legacy NLI)' do
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Test J9U Person',
          fname: 'j9u_only.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/j9u_only.php')
        }
      )
    end

    it 'stores the J9U value as nli' do
      call
      entry = file.lex_entry
      expect(entry.external_identifiers).to eq('nli' => '987007258174109999')
      expect(entry.external_identifiers).not_to have_key('j9u')
    end
  end

  context 'when span wraps all page content (no </span> before Books section)' do
    # Regression test for 00633.php: when the <span dir="rtl"> before <body> is never closed
    # before the Books section, Nokogiri parses everything inside the span. The original code
    # jumped to the span's parent level and called next_element, finding nothing (span has no
    # next sibling), resulting in 0 LexPersonWorks.
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Example Author',
          fname: 'span_wraps_all.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/span_wraps_all.php')
        }
      )
    end

    it 'parses works correctly even when span wraps all content' do
      expect { call }.to change(LexPerson, :count).by(1)
      expect(file.reload).to be_status_ingested

      person = file.lex_entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person.works.count).to eq(2)
      expect(person.works.map(&:title)).to include('ספר ראשון : שירים', 'ספר שני : פרוזה')
      expect(person.works.all?(&:work_type_original?)).to be true
    end
  end

  context 'when bio is inside the heading span but works header is outside it' do
    # Regression test for 00118.php: the <span dir="rtl"> wraps only the heading table
    # and the bio <p>, but the Books header <font> and works are siblings of the span.
    # The old promotion logic (heading_table = span) caused the bio <p> to be skipped
    # because span.next_element immediately hit the Books header.
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'סופרת לדוגמה',
          fname: 'bio_in_span_works_outside.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/bio_in_span_works_outside.php')
        }
      )
    end

    it 'ingests bio and works correctly' do
      expect { call }.to change(LexPerson, :count).by(1)

      person = file.lex_entry.lex_item
      expect(person.bio).to be_present
      expect(person.bio).to include('ביוגרפיה קצרה')
      expect(person.works.count).to eq(2)
      expect(person.works.map(&:title)).to include('ספר ראשון : שירים', 'ספר שני : פרוזה')
    end
  end

  context 'when life years are split across font elements in the heading table' do
    # tsifroni.php has "(1915" and "─2011)" in separate <font> elements, so the
    # HTML-regex path fails. The fallback must parse years from the cell's text content.
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'גבריאל צפרוני',
          fname: 'tsifroni.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/tsifroni.php')
        }
      )
    end

    before { allow(Lexicon::ParseCitations).to receive(:call).and_return([]) }

    it 'extracts birthdate and deathdate from heading cell text' do
      expect { call }.to change(LexPerson, :count).by(1)

      person = file.lex_entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person).to have_attributes(birthdate: '1915', deathdate: '2011')
      expect(person.gender).to eq('male')
    end
  end

  context 'when a link has href as its only attribute (no target="_blank")' do
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Test Person',
          fname: 'href_only_link.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/href_only_link.php')
        }
      )
    end

    it 'migrates all links including href-only links' do
      expect { call }.to change(LexPerson, :count).by(1)

      person = file.lex_entry.lex_item
      expect(person.links.count).to eq(2)
      expect(person.links.map(&:url)).to include(
        'http://www.example.com/with-target',
        'http://www.ynet.co.il/articles/0,7340,L-3132749,00.html'
      )
    end
  end

  context 'when both birthdate and deathdate provided', vcr: { cassette_name: 'lexicon/ingest_person/00024' } do
    let(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Samuel Bass',
          entry_status: :raw,
          fname: '00024.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/00024.php')
        }
      )
    end

    it 'parses file successfully' do
      expect { call }.to change(LexPerson, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      person = entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person).to have_attributes(birthdate: '1899', deathdate: '1949')
      expect(person.gender).to eq('male')
      expect(person.citations.count).to eq(4)
      expect(person.citations.select { |c| c.person_work.present? }.size).to eq(1)
      # There is a discrepancy between the book name in file and the citation subject for 3 citations
      expect(person.citations.select { |c| c.subject.present? }.size).to eq(3)
      expect(person.works.count).to eq(22)
      expect(person.works.select(&:work_type_original?).size).to eq(18)
      expect(person.works.select(&:work_type_edited?).size).to eq(2)
      expect(person.works.select(&:work_type_translated?).size).to eq(2)

      expect(entry.english_title).to eq('Samuel Bass')

      expect(entry.external_identifiers).to be_nil
    end
  end

  context 'when citations header is malformed', vcr: { cassette_name: 'lexicon/ingest_person/00020' } do
    # In this file citations header is added at the end of Works list
    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Judith Rotem',
          fname: '00020.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/00020.php')
        }
      )
    end

    it 'parses file successfully' do
      expect { call }.to change(LexPerson, :count).by(1)

      expect(file.reload).to be_status_ingested
      entry = file.lex_entry
      person = entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person).to have_attributes(birthdate: '1942', deathdate: nil)
      expect(person.gender).to eq('female')
      expect(person.citations.count).to eq(35)
      expect(person.citations.select { |c| c.subject.present? }.size).to eq(5)
      expect(person.citations.select { |c| c.person_work.present? }.size).to eq(24)

      expect(person.works.count).to eq(28)
      expect(person.works.select(&:work_type_original?).size).to eq(12)
      expect(person.works.select(&:work_type_edited?).size).to eq(16)

      expect(entry.english_title).to eq('Judith Rotem')

      expect(person.links).to be_empty
      expect(entry.external_identifiers).to be_nil
    end
  end

  context 'when page contains BYP badge, empty items in works list and malformed citations block',
          vcr: { cassette_name: 'lexicon/ingest_person/04443' } do
    let!(:authority) { create(:authority, name: 'Matthias Simcha Rabener', id: 2575) }

    let!(:file) do
      create(
        :lex_file,
        {
          entrytype: :person,
          status: :classified,
          title: 'Matthias Simcha Rabener',
          fname: '04443.php',
          full_path: Rails.root.join('spec/fixtures/files/lexicon/04443.php')
        }
      )
    end

    it 'parses file successfully' do
      expect { call }.to change(LexPerson, :count).by(1)

      expect(file.reload).to be_status_ingested
      entry = file.lex_entry
      person = entry.lex_item
      expect(person).to be_an_instance_of(LexPerson)
      expect(person).to have_attributes(birthdate: '1826', deathdate: '1894')
      expect(person.gender).to eq('male')
      expect(person.citations.count).to eq(2)
      expect(person.citations.select { |c| c.subject.nil? && c.person_work.nil? }.size).to eq(2)

      expect(person.works.count).to eq(0)
      expect(person.authority).to eq(authority)

      expect(entry.english_title).to eq('Matthias Simcha Rabener')

      expect(person.links).to be_empty
      expect(entry.external_identifiers).to eq(
        {
          'lc' => 'nb2009008724',
          'nli' => '987007519078905171',
          'openlibrary' => 'OL13430890A',
          'viaf' => '141147266569335480503',
          'wikidata' => 'Q12409731'
        }
      )
    end
  end

  describe '#attach_backup_files (private)' do
    it 'attaches the blob from LexEntry to the citation backup_file when backup_url matches a LexLegacyLink' do
      entry = create(:lex_entry)
      entry.attachments.attach(
        io: StringIO.new('pdf content'),
        filename: 'article.pdf',
        content_type: 'application/pdf'
      )
      blob = entry.attachments.first.blob
      new_path = entry.download_path('article.pdf')

      create(:lex_legacy_link, lex_entry: entry, old_path: '00024-files/article.pdf', new_path: new_path)

      lex_person = create(:lex_person)
      citation = create(:lex_citation, person: lex_person, title: 'Test', backup_url: new_path)

      expect do
        described_class.new.send(:attach_backup_files, lex_person)
      end.to change { citation.reload.backup_file.attached? }.from(false).to(true)

      expect(citation.backup_file.blob).to eq(blob)
    end

    it 'skips citations with no backup_url' do
      lex_person = create(:lex_person)
      create(:lex_citation, person: lex_person, title: 'No backup', backup_url: nil)

      expect do
        described_class.new.send(:attach_backup_files, lex_person)
      end.not_to(change(ActiveStorage::Attachment, :count))
    end

    it 'skips citations whose backup_url has no matching LexLegacyLink' do
      lex_person = create(:lex_person)
      create(:lex_citation, person: lex_person, title: 'External only',
                            backup_url: 'https://archive.today/abc123')

      expect do
        described_class.new.send(:attach_backup_files, lex_person)
      end.not_to(change(ActiveStorage::Attachment, :count))
    end
  end
end
