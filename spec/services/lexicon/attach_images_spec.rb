# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::AttachImages do
  subject(:call) { described_class.call(html_doc, lex_entry) }

  let(:html_doc) { Nokogiri::HTML::Document.parse(html) }

  let(:html) do
    <<~HTML
      <img id="static" src="00000_files/blank.png"/>
      <img id="local" src="00123_files/test.png"/>
      <img id="external" src="https://somewhere.com/external.png"/>
    HTML
  end

  let(:lex_file) { create(:lex_file, :person, fname: '00123.php') }
  let(:lex_entry) { lex_file.lex_entry }

  before do
    allow(Lexicon::MigrateAttachment).to receive(:call).with('00123_files/test.png', lex_entry)
                                                       .and_return('new_test_image.png')
    # for external image we call original implementation (it should return nil)
    allow(Lexicon::MigrateAttachment).to receive(:call).with('https://somewhere.com/external.png', lex_entry)
                                                       .and_call_original
  end

  it 'correctly converts links to images' do
    call
    expect(html_doc.at_css('#static')['src']).to eq('/lex/blank.png')
    expect(html_doc.at_css('#local')['src']).to eq('new_test_image.png')
    expect(html_doc.at_css('#external')['src']).to eq('https://somewhere.com/external.png')
  end
end
