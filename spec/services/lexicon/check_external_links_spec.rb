# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::CheckExternalLinks do
  include WebMock::API

  subject(:call) { described_class.call(entry) }

  let(:person) { create(:lex_person) }
  let(:entry) { create(:lex_entry, :person, lex_item: person) }

  before do
    # WebMock blocks all real HTTP connections in tests; we stub selectively below.
    WebMock.disable_net_connect!(allow_localhost: true)
    # Default: allow Resolv to resolve stubbed hostnames to a public IP.
    allow(Resolv).to receive(:getaddresses).and_return(['93.184.216.34'])
  end

  context 'when entry has no lex_item' do
    let(:entry) { create(:lex_entry, lex_item: nil, status: :raw) }

    it 'does nothing and does not raise' do
      expect { call }.not_to raise_error
    end
  end

  context 'when the person has no links or citations with links' do
    it 'does nothing' do
      expect { call }.not_to change(LexLink, :count)
    end
  end

  context 'with a working link (HTTP 200)' do
    let!(:link) { create(:lex_link, item: person, url: 'http://example.com/ok') }

    before do
      stub_request(:head, 'http://example.com/ok').to_return(status: 200)
    end

    it 'records 200 on the link' do
      call
      expect(link.reload.http_status).to eq(200)
    end
  end

  context 'with a broken link (HTTP 404)' do
    let!(:link) { create(:lex_link, item: person, url: 'http://example.com/missing') }

    before do
      stub_request(:head, 'http://example.com/missing').to_return(status: 404)
    end

    it 'records 404 on the link' do
      call
      expect(link.reload.http_status).to eq(404)
    end

    it 'marks the link as broken' do
      call
      expect(link.reload).to be_broken
    end
  end

  context 'with a server error link (HTTP 500)' do
    let!(:link) { create(:lex_link, item: person, url: 'http://example.com/error') }

    before do
      stub_request(:head, 'http://example.com/error').to_return(status: 500)
    end

    it 'records 500 and marks broken' do
      call
      expect(link.reload.http_status).to eq(500)
      expect(link.reload).to be_broken
    end
  end

  context 'with a redirect link (HTTP 301) that resolves to 200' do
    let!(:link) { create(:lex_link, item: person, url: 'http://example.com/old') }

    before do
      stub_request(:head, 'http://example.com/old')
        .to_return(status: 301, headers: { 'Location' => 'http://example.com/new' })
      stub_request(:head, 'http://example.com/new').to_return(status: 200)
    end

    it 'follows the redirect and records 200' do
      call
      expect(link.reload.http_status).to eq(200)
      expect(link.reload).not_to be_broken
    end
  end

  context 'with a redirect that leads to a 404' do
    let!(:link) { create(:lex_link, item: person, url: 'http://example.com/gone') }

    before do
      stub_request(:head, 'http://example.com/gone')
        .to_return(status: 302, headers: { 'Location' => 'http://example.com/notfound' })
      stub_request(:head, 'http://example.com/notfound').to_return(status: 404)
    end

    it 'follows redirect and records 404 as broken' do
      call
      expect(link.reload.http_status).to eq(404)
      expect(link.reload).to be_broken
    end
  end

  # Many servers reject the HEAD method with something other than the correct 405 -- notably a
  # bare 403, which is indistinguishable from "broken" unless we retry with GET.
  describe 'falling back to GET when the server rejects HEAD' do
    [400, 403, 405, 501].each do |head_status|
      context "when HEAD returns #{head_status} but GET succeeds" do
        let!(:link) { create(:lex_link, item: person, url: 'http://example.com/head-rejected') }

        before do
          stub_request(:head, 'http://example.com/head-rejected').to_return(status: head_status)
          stub_request(:get, 'http://example.com/head-rejected').to_return(status: 200)
        end

        it 'records 200 and does not mark the link broken' do
          call
          expect(link.reload.http_status).to eq(200)
          expect(link.reload).not_to be_broken
        end
      end
    end

    context 'when both HEAD and GET are refused (genuinely gated or broken)' do
      let!(:link) { create(:lex_link, item: person, url: 'http://example.com/gated') }

      before do
        stub_request(:head, 'http://example.com/gated').to_return(status: 403)
        stub_request(:get, 'http://example.com/gated').to_return(status: 403)
      end

      it 'records the 403 and marks the link broken' do
        call
        expect(link.reload.http_status).to eq(403)
        expect(link.reload).to be_broken
      end
    end

    context 'when HEAD returns a status that is not a HEAD rejection' do
      let!(:link) { create(:lex_link, item: person, url: 'http://example.com/really-missing') }

      before do
        stub_request(:head, 'http://example.com/really-missing').to_return(status: 404)
      end

      it 'does not retry with GET' do
        call
        expect(link.reload.http_status).to eq(404)
        assert_not_requested(:get, 'http://example.com/really-missing')
      end
    end
  end

  # Regression: www.text.org.il's mod_security rules 403 any User-Agent containing "link"
  # (matching "linkchecker"), which made every link on that host look broken. See #1594.
  describe 'the User-Agent sent to external servers' do
    # WebMock's request registry is not reset between examples in this file, so each example
    # uses its own URL to keep request counts from leaking into the next one.
    let!(:link) { create(:lex_link, item: person, url: url) }

    before { stub_request(:head, url).to_return(status: 200) }

    context 'when checking a link' do
      let(:url) { 'http://example.com/ua-no-link-token' }

      it 'sends no User-Agent containing "link", which trips stock bad-bot WAF rules' do
        call
        assert_not_requested(:head, url, headers: { 'User-Agent' => /link/i })
      end
    end

    context 'when identifying ourselves' do
      let(:url) { 'http://example.com/ua-identifies-project' }

      it 'names the project and its URL' do
        call
        assert_requested(:head, url,
                         headers: { 'User-Agent' => %r{\AProject-Ben-Yehuda/.*benyehuda\.org} })
      end
    end
  end

  context 'when network connection fails' do
    let!(:link) { create(:lex_link, item: person, url: 'http://unreachable.example.com/') }

    before do
      stub_request(:head, 'http://unreachable.example.com/').to_raise(Errno::ECONNREFUSED)
    end

    it 'writes nil to http_status (clears any stale value)' do
      link.update_column(:http_status, 200) # simulate prior check
      call
      expect(link.reload.http_status).to be_nil
    end

    it 'marks the link broken and records when it was checked' do
      call
      link.reload
      expect(link).to be_broken
      expect(link.checked_at).to be_present
    end
  end

  context 'with an invalid URL' do
    let!(:link) { create(:lex_link, item: person, url: 'not-a-url') }

    it 'writes nil and does not raise' do
      expect { call }.not_to raise_error
      expect(link.reload.http_status).to be_nil
    end
  end

  context 'with a non-HTTP URL (e.g. mailto:)' do
    let!(:link) { create(:lex_link, item: person, url: 'mailto:someone@example.com') }

    it 'writes nil' do
      expect { call }.not_to raise_error
      expect(link.reload.http_status).to be_nil
    end
  end

  context 'with a local file path URL (e.g. /files/lex/...)' do
    let!(:link) { create(:lex_link, item: person, url: '/files/lex/7635/doc.pdf') }

    it 'does not attempt to check the URL' do
      call
      expect(link.reload.checked_at).to be_nil
      expect(link.reload.http_status).to be_nil
    end

    it 'does not mark the link as broken' do
      call
      expect(link.reload).not_to be_broken
    end
  end

  context 'with SSRF protection against private/loopback addresses' do
    context 'when the URL resolves to a loopback address (127.0.0.1)' do
      let!(:link) { create(:lex_link, item: person, url: 'http://internal.example.com/secret') }

      before do
        allow(Resolv).to receive(:getaddresses).with('internal.example.com').and_return(['127.0.0.1'])
      end

      it 'does not make an HTTP request and writes nil' do
        call
        assert_not_requested(:any, 'http://internal.example.com/secret')
        expect(link.reload.http_status).to be_nil
      end
    end

    context 'when the URL resolves to a private RFC1918 address' do
      let!(:link) { create(:lex_link, item: person, url: 'http://private.example.com/data') }

      before do
        allow(Resolv).to receive(:getaddresses).with('private.example.com').and_return(['192.168.1.100'])
      end

      it 'does not connect and writes nil' do
        call
        expect(link.reload.http_status).to be_nil
      end
    end

    context 'when DNS resolution fails' do
      let!(:link) { create(:lex_link, item: person, url: 'http://nonexistent.example.com/') }

      before do
        allow(Resolv).to receive(:getaddresses).with('nonexistent.example.com')
                                               .and_raise(Resolv::ResolvError)
      end

      it 'does not connect and writes nil' do
        call
        expect(link.reload.http_status).to be_nil
      end

      it 'marks the link broken (host is defunct)' do
        call
        link.reload
        expect(link).to be_broken
        expect(link.checked_at).to be_present
      end
    end
  end

  context 'when person has a citation with a broken link' do
    let(:citation) { create(:lex_citation, person: person, link: 'http://example.com/cit-broken') }

    before do
      citation # materialize
      stub_request(:head, 'http://example.com/cit-broken').to_return(status: 410)
    end

    it 'records the HTTP status on the citation' do
      call
      expect(citation.reload.link_http_status).to eq(410)
    end

    it 'marks the citation link as broken' do
      call
      expect(citation.reload).to be_link_broken
    end
  end

  context 'when person has a citation with a working link' do
    let(:citation) { create(:lex_citation, person: person, link: 'http://example.com/cit-ok') }

    before do
      citation
      stub_request(:head, 'http://example.com/cit-ok').to_return(status: 200)
    end

    it 'records 200 on the citation link' do
      call
      expect(citation.reload.link_http_status).to eq(200)
      expect(citation.reload).not_to be_link_broken
    end
  end

  context 'when person has a citation without a link' do
    let!(:citation) { create(:lex_citation, person: person, link: nil) }

    it 'does not check and leaves link_http_status nil' do
      call
      expect(citation.reload.link_http_status).to be_nil
    end
  end

  context 'when person has a citation with a local file path link' do
    let!(:citation) { create(:lex_citation, person: person, link: '/files/lex/7635/article.pdf') }

    it 'does not attempt to check the URL' do
      call
      expect(citation.reload.link_checked_at).to be_nil
      expect(citation.reload.link_http_status).to be_nil
    end

    it 'does not mark the citation link as broken' do
      call
      expect(citation.reload).not_to be_link_broken
    end
  end

  context 'when person has a citation with a local internal URL' do
    let!(:citation) { create(:lex_citation, person: person, link: '/lex/entries/1234#no5') }

    it 'does not attempt to check the URL and does not mark broken' do
      call
      expect(citation.reload.link_checked_at).to be_nil
      expect(citation.reload).not_to be_link_broken
    end
  end

  context 'when citation check fails (network error)' do
    let(:citation) { create(:lex_citation, person: person, link: 'http://example.com/cit-fail') }

    before do
      citation
      stub_request(:head, 'http://example.com/cit-fail').to_raise(Errno::ECONNREFUSED)
    end

    it 'writes nil to link_http_status (clears any stale value)' do
      citation.update_column(:link_http_status, 200) # simulate prior check
      call
      expect(citation.reload.link_http_status).to be_nil
    end

    it 'marks the citation link broken and records when it was checked' do
      call
      citation.reload
      expect(citation).to be_link_broken
      expect(citation.link_checked_at).to be_present
    end
  end

  context 'with a LexPublication entry' do
    let(:publication) { create(:lex_publication) }
    let(:entry) { create(:lex_entry, :publication, lex_item: publication) }
    let!(:link) { create(:lex_link, item: publication, url: 'http://example.com/pub-ok') }

    before do
      stub_request(:head, 'http://example.com/pub-ok').to_return(status: 200)
    end

    it 'checks publication links' do
      call
      expect(link.reload.http_status).to eq(200)
    end
  end
end
