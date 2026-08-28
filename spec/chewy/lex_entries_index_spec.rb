# frozen_string_literal: true

require 'rails_helper'

describe LexEntriesIndex do
  let(:lex_entry) { create(:lex_entry, :person, status: :published, title: 'Test Lexicon Entry') }

  before do
    clean_tables
    lex_entry.lex_item.update!(
      bio: '<img src="/files/lex/1/photo.jpg" width="200" /><span>נולד בוורשה</span><br />ועלה לארץ'
    )
    import_and_await(described_class, LexEntry.status_published)
  end

  after { Chewy.massacre }

  it 'indexes the bio as plain text rather than HTML' do
    fulltext = described_class.filter(term: { id: lex_entry.id }).first.fulltext

    expect(fulltext).to include('נולד בוורשה')
    expect(fulltext).to include('ועלה לארץ')
    expect(fulltext).not_to include('<img')
    expect(fulltext).not_to include('photo.jpg')
    expect(fulltext).not_to include('<span>')
  end
end
