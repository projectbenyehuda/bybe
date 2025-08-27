# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/files' do
  describe '#index' do
    subject(:call) { get '/lex/files' }

    before do
      create_list(:lex_file, 2, :person, status: :classified)
      create_list(:lex_file, 2, :person, status: :ingested)
      create_list(:lex_file, 2, :publication, status: :classified)
      create_list(:lex_file, 2, :publication, status: :ingested)
    end

    it 'renders successfully' do
      expect(call).to eq(200)
    end
  end

  describe 'POST /migrate_person' do
    subject(:call) { post "/lex/files/#{file.id}/migrate_person" }

    let!(:file) do
      create(
        :lex_file,
        :person,
        entrytype: :person,
        status: :classified,
        title: 'Gabriella Avigur',
        fname: '/00002.php',
        full_path: Rails.root.join('spec/data/lexicon/00002.php')
      )
    end

    it 'creates new LexEntry and LexPerson' do
      expect { call }.to change(LexPerson, :count).by(1).and change(LexEntry, :count).by(1)
      expect(call).to redirect_to lexicon_person_path(LexEntry.last.lex_item)
    end
  end

  describe 'POST /migrate_publication' do
    subject(:call) { post "/lex/files/#{file.id}/migrate_publication" }

    let!(:file) do
      create(
        :lex_file,
        :publication,
        entrytype: :text,
        status: :classified,
        title: 'Gabriella Avigur',
        fname: '/02645001.php',
        full_path: Rails.root.join('spec/data/lexicon/02645001.php')
      )
    end

    it 'creates new LexEntry and LexPublication' do
      expect { call }.to change(LexPublication, :count).by(1).and change(LexEntry, :count).by(1)
      expect(call).to redirect_to lexicon_publication_path(LexEntry.last.lex_item)
    end
  end
end
