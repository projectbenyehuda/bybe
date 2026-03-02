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
          full_path: Rails.root.join('spec/data/lexicon/00002.php')
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

      # External identifiers
      expect(entry.external_identifiers).to include(
        'openlibrary' => 'OL4181279A',
        'wikidata' => 'Q12404844',
        'j9u' => '987007258174105171',
        'nli' => '000013455',
        'lc' => 'n82204318',
        'viaf' => '22255259'
      )
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
          full_path: Rails.root.join('spec/data/lexicon/href_only_link.php')
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
          full_path: Rails.root.join('spec/data/lexicon/00024.php')
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
          full_path: Rails.root.join('spec/data/lexicon/00020.php')
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
end
