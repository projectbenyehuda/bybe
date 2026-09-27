# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::LookupArchiveUrlJob do
  let(:dead_url) { 'https://dead.example.com/page' }
  let(:snapshot) { "https://web.archive.org/web/20200101000000/#{dead_url}" }

  before { allow(Lexicon::WaybackLookup).to receive(:call).with(dead_url).and_return(snapshot) }

  def broken_link
    create(:lex_link, url: dead_url, http_status: 404, checked_at: Time.current)
  end

  it 'stores the snapshot of a broken link' do
    link = broken_link
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to eq(snapshot)
  end

  it 'stores the snapshot of a broken citation link' do
    citation = create(:lex_citation, person: create(:lex_person), link: dead_url, link_http_status: 404,
                                     link_checked_at: Time.current)
    described_class.perform_now(citation, dead_url)
    expect(citation.reload.link_archive_url).to eq(snapshot)
  end

  it 'leaves a link alone once its URL has changed again' do
    link = create(:lex_link, url: 'https://elsewhere.example.com/', http_status: 404, checked_at: Time.current)
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to be_nil
  end

  # A slow lookup must not put back a snapshot after a later check of the same URL found it working
  it 'leaves a link alone once a later check found it working' do
    link = create(:lex_link, url: dead_url, http_status: 200, checked_at: Time.current)
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to be_nil
  end

  it 'does not overwrite a snapshot a later check already stored' do
    newer = 'https://web.archive.org/web/20250101000000/https://dead.example.com/page'
    link = create(:lex_link, url: dead_url, http_status: 404, checked_at: Time.current, archive_url: newer)
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to eq(newer)
  end

  it 'stores nothing when no snapshot was found' do
    allow(Lexicon::WaybackLookup).to receive(:call).and_return(nil)
    link = broken_link
    described_class.perform_now(link, dead_url)
    expect(link.reload.archive_url).to be_nil
  end
end
