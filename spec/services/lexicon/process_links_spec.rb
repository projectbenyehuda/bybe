# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::ProcessLinks do
  subject(:call) { described_class.call(html_doc, lex_entry) }

  let(:html) do
    <<~HTML
      <ul>
        <li><a id="link_1" href="123_files/test.pdf">Attachment Link</a></li>
        <li><a id="link_2" href="https://google.com">External Link</a></li>
        <li><a id="link_3" href="#anchor">Local Link</a></li>
        <li><a id="link_4" href="">Empty Link</a></li>
        <li><a id="link_5" href="hbe/hbe00898.php">HBE Link</a></li>
        <li><a id="link_6" href="12345.php">Existing Lexicon Page</a></li>
        <li><a id="link_7" href="12345.php#תווית">Existing Lexicon Page with an Anchor</a></li>
        <li><a id="link_8" href="98765.php">Missing Lexicon Page</a></li>
        <li><a id="link_9" href="index.htm">Lexicon root page</a></li>
      </ul>
    HTML
  end

  let!(:existing_lex_file) { create(:lex_file, :person, fname: '12345.php') }
  let(:existing_lex_entry) { existing_lex_file.lex_entry }

  let(:html_doc) { Nokogiri.parse(html) }

  let(:lex_entry) { build(:lex_entry) }

  before do
    # stubbing attachment migration
    allow(Lexicon::MigrateAttachment).to receive(:call).with('123_files/test.pdf', lex_entry)
                                                       .and_return('new_attachment_link')

    allow(Lexicon::MigrateAttachment).to receive(:call).with('https://google.com', lex_entry).and_call_original
    call
  end

  it 'Updates links where necessary' do
    expect(html_doc.at_css('#link_1')['href']).to eq('new_attachment_link')
    expect(html_doc.at_css('#link_2')['href']).to eq('https://google.com')
    expect(html_doc.at_css('#link_3')['href']).to eq('#anchor')
    expect(html_doc.at_css('#link_4')['href']).to eq('')
    expect(html_doc.at_css('#link_5')['href']).to eq('/lexicon/hbe/hbe00898.php')
    expect(html_doc.at_css('#link_6')['href']).to eq("/lex/entries/#{existing_lex_entry.id}")
    expect(html_doc.at_css('#link_7')['href']).to eq("/lex/entries/#{existing_lex_entry.id}#תווית")
    expect(html_doc.at_css('#link_8')['href']).to eq('98765.php') # not changed as there is no matching lexicon entry
    expect(html_doc.at_css('#link_9')['href']).to eq('/lex')
  end
end
