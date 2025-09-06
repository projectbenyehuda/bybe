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
        title: 'Eliezer Jerushalmi',
        fname: '02645001.php',
        full_path: Rails.root.join('spec/data/lexicon/02645001.php')
      }
    )
  end

  it 'parses file successfully' do
    expect { call }.to change(LexEntry, :count).by(1).and change(LexPublication, :count).by(1)
    expect(file.reload).to be_status_ingested

    entry = file.lex_entry
    expect(entry).to have_attributes(legacy_filename: '02645001.php', title: 'Eliezer Jerushalmi')

    publication = entry.lex_item
    expect(publication).to be_an_instance_of(LexPublication)
    expect(publication).to have_attributes(az_navbar: true)
    expect(publication.entry.attachments.count).to eq(1)
  end
end
