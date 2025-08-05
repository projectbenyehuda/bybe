# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::IngestPerson do
  subject(:call) { described_class.call(file.id) }

  let!(:file) do
    create(
      :lex_file,
      {
        entrytype: :person,
        status: :classified,
        title: 'Gabriella Avigur',
        fname: '/00002.php',
        full_path: Rails.root.join('spec', 'data', 'lexicon', '00002.php')
      }
    )
  end

  it 'parses file successfully' do
    expect { call }.to change { LexEntry.count }.by(1).and change { LexPerson.count }.by(1)

    expect(file.reload).to be_status_ingested

  end
end