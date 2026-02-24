# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::AssociateAuthority do
  include WebMock::API

  subject(:call) { described_class.call(lex_person, html_doc) }

  let(:html_doc) { Nokogiri::HTML(html_body) }
  let(:html_body) { '<html><body></body></html>' }

  let(:lex_person) do
    create(:lex_file, entrytype: :person, status: :classified,
                      title: entry_title, fname: 'test.php',
                      full_path: Rails.root.join('spec/data/lexicon/no_links.php'))
      .lex_entry
      .tap(&:status_draft!)
      .lex_item
  end

  let(:entry_title) { 'ישראלי, ישראל' }

  shared_examples 'associates authority' do
    it 'sets the authority on lex_person and saves' do
      call
      expect(lex_person.reload.authority).to eq(expected_authority)
    end
  end

  shared_examples 'does not associate authority' do
    it 'leaves lex_person.authority nil' do
      call
      expect(lex_person.reload.authority).to be_nil
    end
  end

  context 'when the PHP file links to benyehuda.org/author/:id' do
    let(:expected_authority) { create(:authority) }
    let(:html_body) do
      "<html><body><a href=\"https://benyehuda.org/author/#{expected_authority.id}\">ben-yehuda</a></body></html>"
    end

    it_behaves_like 'associates authority'
  end

  context 'when the PHP file links to www.benyehuda.org/author/:id' do
    let(:expected_authority) { create(:authority) }
    let(:html_body) do
      "<html><body><a href=\"https://www.benyehuda.org/author/#{expected_authority.id}\">ben-yehuda</a></body></html>"
    end

    it_behaves_like 'associates authority'
  end

  context 'when benyehuda.org /author/:id does not match any Authority' do
    let(:html_body) do
      '<html><body><a href="https://benyehuda.org/author/999999">ben-yehuda</a></body></html>'
    end

    it_behaves_like 'does not associate authority'
  end

  context 'when the PHP file links to benyehuda.org with a slug matched by HtmlDir' do
    let(:expected_authority) { create(:authority) }
    let(:html_body) do
      '<html><body><a href="https://benyehuda.org/shats">ben-yehuda</a></body></html>'
    end

    before { HtmlDir.create!(path: 'shats', person_id: expected_authority.id, author: 'Shats') }

    it_behaves_like 'associates authority'
  end

  context 'when benyehuda.org slug has no matching HtmlDir record' do
    let(:html_body) do
      '<html><body><a href="https://benyehuda.org/nonexistent_slug">ben-yehuda</a></body></html>'
    end

    it_behaves_like 'does not associate authority'
  end

  context 'when Wikidata item has the P7507 property' do
    let(:expected_authority) { create(:authority) }
    let(:wikidata_response) do
      {
        'type' => 'item', 'id' => 'Q12404844',
        'statements' => {
          'P7507' => [
            { 'value' => { 'type' => 'value', 'content' => expected_authority.id.to_s } }
          ]
        }
      }.to_json
    end
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/entity/Q12404844">Q12404844</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q12404844')
        .to_return(status: 200, body: wikidata_response, headers: { 'Content-Type' => 'application/json' })
    end

    it_behaves_like 'associates authority'
  end

  context 'when the Wikidata URL uses the wiki-style /wiki/ path' do
    let(:expected_authority) { create(:authority) }
    let(:wikidata_response) do
      {
        'statements' => {
          'P7507' => [{ 'value' => { 'type' => 'value', 'content' => expected_authority.id.to_s } }]
        }
      }.to_json
    end
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/wiki/Q99">Q99</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q99')
        .to_return(status: 200, body: wikidata_response, headers: { 'Content-Type' => 'application/json' })
    end

    it_behaves_like 'associates authority'
  end

  context 'when Wikidata item has no P7507 property' do
    let(:wikidata_response) do
      { 'type' => 'item', 'id' => 'Q12404844', 'statements' => { 'P31' => [] } }.to_json
    end
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/entity/Q12404844">Q12404844</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q12404844')
        .to_return(status: 200, body: wikidata_response, headers: { 'Content-Type' => 'application/json' })
    end

    it_behaves_like 'does not associate authority'
  end

  context 'when Wikidata P7507 points to a non-existent Authority' do
    let(:wikidata_response) do
      {
        'statements' => {
          'P7507' => [{ 'value' => { 'type' => 'value', 'content' => '999999' } }]
        }
      }.to_json
    end
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/entity/Q12404844">Q12404844</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q12404844')
        .to_return(status: 200, body: wikidata_response, headers: { 'Content-Type' => 'application/json' })
    end

    it_behaves_like 'does not associate authority'
  end

  context 'when Wikidata API returns an error response' do
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/entity/Q12404844">Q12404844</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q12404844')
        .to_return(status: 404, body: '{"error":"not found"}')
    end

    it_behaves_like 'does not associate authority'
  end

  context 'when exactly one Authority matches the entry title by name' do
    let(:expected_authority) { create(:authority, name: entry_title) }

    before { expected_authority }

    it_behaves_like 'associates authority'
  end

  context 'when multiple Authorities have the same name' do
    before { create_list(:authority, 2, name: entry_title) }

    it_behaves_like 'does not associate authority'
  end

  context 'when no Authority has a matching name' do
    it_behaves_like 'does not associate authority'
  end

  context 'when both a benyehuda.org link and a name match exist' do
    let(:authority_by_link) { create(:authority) }
    let(:html_body) do
      "<html><body><a href=\"https://benyehuda.org/author/#{authority_by_link.id}\">link</a></body></html>"
    end

    before do
      authority_by_link
      create(:authority, name: entry_title) # name match — must NOT win
    end

    it 'associates via the benyehuda.org link, not the name' do
      call
      expect(lex_person.reload.authority).to eq(authority_by_link)
    end
  end

  context 'when both a Wikidata link and a name match exist' do
    let(:expected_authority) { create(:authority) }
    let(:wikidata_response) do
      {
        'statements' => {
          'P7507' => [{ 'value' => { 'type' => 'value', 'content' => expected_authority.id.to_s } }]
        }
      }.to_json
    end
    let(:html_body) do
      '<html><body><a href="https://www.wikidata.org/entity/Q12404844">Q12404844</a></body></html>'
    end

    before do
      stub_request(:get, 'https://www.wikidata.org/w/rest.php/wikibase/v1/entities/items/Q12404844')
        .to_return(status: 200, body: wikidata_response, headers: { 'Content-Type' => 'application/json' })
      create(:authority, name: entry_title) # name match — must NOT win
    end

    it_behaves_like 'associates authority'
  end
end
