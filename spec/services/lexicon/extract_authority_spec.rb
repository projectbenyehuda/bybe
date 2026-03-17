# frozen_string_literal: true
require 'rails_helper'

describe Lexicon::ExtractAuthority do
  subject(:result) { described_class.call(html_doc) }

  let(:html_doc) { Nokogiri::HTML(html) }

  context 'when document does not contain the badge image' do
    let(:html) do
      '<html><body><p>No badge here</p></body></html>'
    end

    it 'returns nil' do
      expect(result).to be_nil
    end
  end

  context 'when badge image is present but not wrapped in an anchor' do
    let(:html) do
      '<html><body><p><img src="/lex/Ben-Yehuda-s.jpg" /></p></body></html>'
    end

    it 'returns nil and leaves the image in place' do
      expect(result).to be_nil
      expect(html_doc.at_css('img[src="/lex/Ben-Yehuda-s.jpg"]')).to be_present
    end
  end

  context 'when image is wrapped in an anchor with a non-matching href' do
    let(:html) do
      <<~HTML.squish
        <html><body>
          <a href="https://benyehuda.org/author/abc">
            <img src="/lex/Ben-Yehuda-s.jpg" />
          </a>
        </body></html>
      HTML
    end

    it 'returns nil and keeps the anchor in the document' do
      expect(result).to be_nil
      expect(html_doc.at_css('a')).to be_present
    end
  end

  context 'when image is wrapped in an anchor with a matching author url' do
    let(:html) do
      <<~HTML.squish
        <html><body>
          <a href="https://benyehuda.org/author/#{authority_id}">
            <img src="/lex/Ben-Yehuda-s.jpg" />
          </a>
        </body></html>
      HTML
    end

    context 'when authority with given id is not found in database' do
      let(:authority_id) { 0 }

      it 'removes badge and returns nil' do
        expect(result).to be_nil
        expect(html_doc.at_css('a')).to be_nil
      end
    end

    context 'when authority with given id is found in database' do
      let(:authority) { create(:authority) }
      let(:authority_id) { authority.id }

      it 'removes badge and returns authority' do
        expect(result).to eq authority
        expect(html_doc.at_css('a')).to be_nil
      end
    end
  end

  context 'when anchor is wrapped in a td tag' do
    let(:html) do
      <<~HTML.squish
        <html><body>
          <table>
            <tbody>
              <tr>
                <td>
                  <a href="https://benyehuda.org/author/#{authority.id}">
                    <img src="/lex/Ben-Yehuda-s.jpg" />
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </body></html>
      HTML
    end

    context 'when authority with given id is found in database' do
      let(:authority) { create(:authority) }

      it 'removes badge with td tag and returns authority' do
        expect(result).to eq authority
        expect(html_doc.at_css('td')).to be_nil
      end
    end
  end
end
