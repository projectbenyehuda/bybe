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
        <li><a id="link_5" href="hbe/hbe00898.php">HBE Link</li>
      </ul>  
    HTML
  end

  let(:html_doc) { Nokogiri.parse(html) }

  let(:lex_entry) { build(:lex_entry) }

  before do
    # stubbing attachment migration
    allow(Lexicon::MigrateAttachment).to receive(:call).with('123_files/test.pdf', lex_entry)
                                                       .and_return('new_attachment_link')

    allow(Lexicon::MigrateAttachment).to receive(:call).with('https://google.com', lex_entry).and_call_original
    call
  end

  it 'Updates links where neccessary' do
    expect(html_doc.at_css('#link_1')['href']).to eq('new_attachment_link')
    expect(html_doc.at_css('#link_2')['href']).to eq('https://google.com')
    expect(html_doc.at_css('#link_3')['href']).to eq('#anchor')
    expect(html_doc.at_css('#link_4')['href']).to eq('')
    expect(html_doc.at_css('#link_5')['href']).to eq('/lexicon/hbe/hbe00898.php')
  end
end
