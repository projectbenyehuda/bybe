# frozen_string_literal: true

require 'rails_helper'

describe '/lexicon/files' do
  describe '#index' do
    subject(:call) { get '/lexicon/files' }

    before do
      create_list(:lex_file, 5, :person, status: :classified)
      create_list(:lex_file, 5, :person, status: :ingested)
    end

    it 'renders successfully' do
      expect(call).to eq(200)
    end
  end

  describe '#migrate_person' do
    subject(:call) { post "/lexicon/files/#{file.id}/migrate_person" }

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
      expect { call }.to change(LexPerson, :count).by(1)
      expect(call).to eq(200)
    end
  end
end
