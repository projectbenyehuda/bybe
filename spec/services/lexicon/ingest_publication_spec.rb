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
      expect(publication.links).to be_empty
      expect(entry.date_of_manual_update).to be_nil
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
      expect(publication.toc).to end_with("רשימת מקורות וציוני הפניות (עמ׳ 285–304)\n\n")
      expect(publication.entry.attachments.count).to eq(1)
      expect(publication.links).to be_empty
      expect(entry.date_of_manual_update).to eq('16 באוקטובר 2024')
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
      expect(publication.description).to end_with("Banbaji\n")
      expect(publication.toc).to start_with("פתח דבר (עמ' 7-10)")
      expect(publication.toc).to end_with("מפתח היצירות (עמ' 393־396)\n\n")

      links = publication.links
      expect(links.size).to eq(1)
      expect(links.first).to have_attributes(
        url: 'http://www.text.org.il/index.php?book=0904057',
        description: " מנדלי והסיפור הלאומי באתר\n\t\tטקסט \n\t\t- כולל הפרק הראשון: מבוא כללי."
      )

      expect(entry.date_of_manual_update).to be_nil
    end
  end

  context 'when TOC header contains linebreaks' do
    let(:title) { 'Mendele Mokher Sefarim' }
    let(:fname) { '00032001.php' }

    it 'parses file successfully', vcr: { cassette_name: 'lexicon/ingest_publication/00032001' } do
      expect { call }.to change(LexPublication, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      publication = entry.lex_item
      expect(publication).to be_an_instance_of(LexPublication)
      expect(publication).to have_attributes(az_navbar: true)
      expect(publication.description).to start_with('<img src="/files/lex/')
      expect(publication.description).to end_with("פולחן.\n\n\n")
      expect(publication.toc).to start_with('מבוא - מחשבות על מאה')
      expect(publication.toc).to end_with("מפתחות (עמ' 419־460)\n\n")
      expect(publication.links).to be_empty
      expect(entry.date_of_manual_update).to be_nil
    end
  end

  context 'when TOC is ended with an HR tag' do
    let(:title) { 'Mendele Mokher Sefarim' }
    let(:fname) { '00086001.php' }

    it 'parses file successfully', vcr: { cassette_name: 'lexicon/ingest_publication/00033001' } do
      expect { call }.to change(LexPublication, :count).by(1)
      expect(file.reload).to be_status_ingested

      entry = file.lex_entry
      publication = entry.lex_item
      expect(publication).to be_an_instance_of(LexPublication)
      expect(publication).to have_attributes(az_navbar: true)
      expect(publication.description).to start_with('<img src="/files/lex/')
      expect(publication.description).to end_with("של ספרותנו, בגילוייה להלכה ולמעשה.\n")
      expect(publication.toc).to start_with("בשער הספר (עמ' 7־9)")
      expect(publication.toc).to end_with("מפתח השמות (עמ' 276־280)\n\n")
      expect(publication.links).to be_empty
      expect(entry.date_of_manual_update).to eq('22 ביולי 2018')
    end
  end
end
