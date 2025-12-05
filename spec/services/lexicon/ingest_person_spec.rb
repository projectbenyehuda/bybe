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
      expect(person.citations.count).to eq(53)
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
      expect(person.citations.count).to eq(4)
    end
  end
end
