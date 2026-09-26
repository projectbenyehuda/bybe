# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::LookupArchiveUrlJob do
  let(:dead_url) { 'https://dead.example.com/page' }
  let(:snapshot) { "https://web.archive.org/web/20200101000000/#{dead_url}" }

  before { allow(Lexicon::WaybackLookup).to receive(:call).with(dead_url).and_return(snapshot) }

  it 'stores the snapshot of a broken link' do
    link = create(:lex_link, url: dead_url)
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to eq(snapshot)
  end

  it 'stores the snapshot of a broken citation link' do
    citation = create(:lex_citation, person: create(:lex_person), link: dead_url)
    described_class.perform_now(citation, dead_url)
    expect(citation.reload.link_archive_url).to eq(snapshot)
  end

  it 'leaves a link alone once its URL has changed again' do
    link = create(:lex_link, url: 'https://elsewhere.example.com/')
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to be_nil
  end

  it 'stores nothing when no snapshot was found' do
    allow(Lexicon::WaybackLookup).to receive(:call).and_return(nil)
    link = create(:lex_link, url: dead_url)
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to be_nil
  end
end
