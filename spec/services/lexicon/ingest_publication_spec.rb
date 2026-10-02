# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::IngestPublication do
  subject(:call) { described_class.call(file) }

  let!(:file) do
    create(
      :lex_file,
      {
        entrytype: :person,
        status: :classified,
        title: title,
        fname: fname,
        full_path: Rails.root.join('spec/fixtures/files/lexicon/', fname)
      }
    )
  end

  context 'when TOC is wrapped with blockquotes' do
    let(:title) { 'Eliezer Jerushalmi' }
    let(:fname) { '02645001.php' }

    it 'parses file successfully', vcr: { cassette_name: 'lexicon/ingest_publication/02645001' } do
      expect { call }.to change(LexPublication, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      publication = entry.lex_item
      expect(publication.description).to start_with('**[אליעזר ירושלמי.]')
      expect(publication.description).to end_with("268 עמ׳.\n")
      expect(publication.toc).to start_with('אמן הנובלה')
      expect(publication.toc).to end_with("(עמ׳ 267–268)\n\n")
      expect(publication.entry.attachments.count).to eq(1)
    end
  end

  context 'when whole file is wrapped with blockquotes' do
    let(:title) { 'As water reflects the face : Bible echoes in literature / Talia Horowitz' }
    let(:fname) { '04398001.php' }

    it 'parses file successfully', vcr: { cassette_name: 'lexicon/ingest_publication/04398001' } do
      expect { call }.to change(LexPublication, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      publication = entry.lex_item
      expect(publication).to be_an_instance_of(LexPublication)
      expect(publication).to have_attributes(az_navbar: true)
      expect(publication.description).to start_with('<img src="/files/lex/')
      expect(publication.description).to end_with("לו שיר מזמור.\n")
      expect(publication.toc).to start_with('פתח דבר')
      expect(publication.toc).to end_with("עודכן לאחרונה: 16 באוקטובר 2024\n\n")

      expect(publication.entry.attachments.count).to eq(1)
    end
  end

  context 'when file has links section after TOC' do
    let(:title) { 'Mendele Mokher Sefarim' }
    let(:fname) { '02002001.php' }

    it 'parses file successfully', vcr: { cassette_name: 'lexicon/ingest_publication/02002001' } do
      expect { call }.to change(LexPublication, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      publication = entry.lex_item
      expect(publication).to be_an_instance_of(LexPublication)
      expect(publication).to have_attributes(az_navbar: true)
      expect(publication.description).to start_with('<img src="/files/lex/')
      expect(publication.description).to end_with("Banbaji</span>\n")
      expect(publication.toc).to start_with("- <span lang=\"he\">פתח דבר (עמ' 7-10)</span>")
      expect(publication.toc).to end_with('393־396)')

      links = publication.links
      expect(links.size).to eq(1)
      expect(links.first).to have_attributes(href: '/files/lex/', description: 'xx')
    end
  end
end
