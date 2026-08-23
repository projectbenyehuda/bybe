# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#staging?' do
    around do |example|
      original_upper = ENV['CACHE_NONCE']
      original_lower = ENV['cache_nonce']
      example.run
      ENV['CACHE_NONCE'] = original_upper
      ENV['cache_nonce'] = original_lower
    end

    it 'returns true when CACHE_NONCE is staging' do
      ENV['CACHE_NONCE'] = 'staging'
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be true
    end

    it 'returns true when cache_nonce (lowercase) is staging' do
      ENV['CACHE_NONCE'] = nil
      ENV['cache_nonce'] = 'staging'
      expect(helper.staging?).to be true
    end

    it 'returns false when neither env var is set' do
      ENV['CACHE_NONCE'] = nil
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be false
    end

    it 'returns false when CACHE_NONCE is set to a different value' do
      ENV['CACHE_NONCE'] = 'production'
      ENV['cache_nonce'] = nil
      expect(helper.staging?).to be false
    end
  end

  # Clears the stamps baked into container images, so the Capistrano fallbacks can be exercised
  # even on a machine where GIT_SHA happens to be exported.
  shared_context 'with no baked-in build stamp' do
    around do |example|
      original_sha = ENV.fetch('GIT_SHA', nil)
      original_committed_at = ENV.fetch('GIT_COMMITTED_AT', nil)
      ENV['GIT_SHA'] = nil
      ENV['GIT_COMMITTED_AT'] = nil
      begin
        example.run
      ensure
        ENV['GIT_SHA'] = original_sha
        ENV['GIT_COMMITTED_AT'] = original_committed_at
      end
  end

  # #show_deployment_version? is covered end-to-end, against the real current_user, in
  # spec/requests/version_indicator_spec.rb -- a helper-spec ActionView::Base has no current_user.

  describe '#deployment_sha' do
    include_context 'with no baked-in build stamp'

    it 'prefers the SHA baked into the container image' do
      ENV['GIT_SHA'] = 'cafebabe1234'
      expect(helper.deployment_sha).to eq 'cafebabe1234'
    end

    it 'falls back to the REVISION file written by Capistrano' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'REVISION'), "deadbeefcafe\n")
        allow(Rails).to receive(:root).and_return(Pathname.new(dir))
        expect(helper.deployment_sha).to eq 'deadbeefcafe'
      end
    end

    it 'is nil when neither is present' do
      Dir.mktmpdir do |dir|
        allow(Rails).to receive(:root).and_return(Pathname.new(dir))
        expect(helper.deployment_sha).to be_nil
      end
    end
  end

  describe '#deployment_time' do
    include_context 'with no baked-in build stamp'

    it 'prefers the commit timestamp baked into the container image' do
      ENV['GIT_COMMITTED_AT'] = '2026-08-20T14:05:00+03:00'
      expect(helper.deployment_time).to eq Time.iso8601('2026-08-20T14:05:00+03:00')
    end

    it 'returns nil rather than raising on a malformed baked-in timestamp' do
      ENV['GIT_COMMITTED_AT'] = '2026-99-99T99:99:99'
      expect(helper.deployment_time).to be_nil
    end

    it 'falls back to the Capistrano release directory name' do
      allow(Rails).to receive(:root).and_return(Pathname.new('/home/bybe/releases/20260731131500'))
      expect(helper.deployment_time).to eq Time.find_zone('UTC').local(2026, 7, 31, 13, 15)
    end
  end

  describe '#deployment_commit_url' do
    include_context 'with no baked-in build stamp'

    it 'links to the deployed commit on GitHub' do
      ENV['GIT_SHA'] = 'cafebabe1234'
      expect(helper.deployment_commit_url).to eq "#{described_class::GITHUB_REPO_URL}/commit/cafebabe1234"
    end

    it 'is nil when the SHA is unknown' do
      Dir.mktmpdir do |dir|
        allow(Rails).to receive(:root).and_return(Pathname.new(dir))
        expect(helper.deployment_commit_url).to be_nil
      end
    end
  end

  describe '#deployment_version' do
    include_context 'with no baked-in build stamp'

    it 'reports the commit stamped into the container image' do
      ENV['GIT_SHA'] = 'cafebabe1234'
      ENV['GIT_COMMITTED_AT'] = '2026-08-20T14:05:00+03:00'
      expected = Time.iso8601('2026-08-20T14:05:00+03:00').in_time_zone.strftime('%Y-%m-%d %H:%M')
      expect(helper.deployment_version).to eq "#{expected} (cafebabe)"
    end

    it 'derives the timestamp from a Capistrano release directory name' do
      allow(Rails).to receive(:root).and_return(Pathname.new('/home/bybe/releases/20260731131500'))
      expected = Time.find_zone('UTC').local(2026, 7, 31, 13, 15).in_time_zone.strftime('%Y-%m-%d %H:%M')
      expect(helper.deployment_version).to eq expected
    end

    it 'appends the short git SHA from the REVISION file' do
      Dir.mktmpdir do |dir|
        release = File.join(dir, '20260731131500')
        Dir.mkdir(release)
        File.write(File.join(release, 'REVISION'), "deadbeefcafe\n")
        allow(Rails).to receive(:root).and_return(Pathname.new(release))
        expected = Time.find_zone('UTC').local(2026, 7, 31, 13, 15).in_time_zone.strftime('%Y-%m-%d %H:%M')
        expect(helper.deployment_version).to eq "#{expected} (deadbeef)"
      end
    end

    it 'falls back to the mtime of the REVISION file' do
      Dir.mktmpdir do |dir|
        revision = File.join(dir, 'REVISION')
        File.write(revision, "deadbeefcafe\n")
        mtime = Time.zone.local(2026, 6, 1, 9, 30)
        File.utime(mtime.to_time, mtime.to_time, revision)
        allow(Rails).to receive(:root).and_return(Pathname.new(dir))
        expect(helper.deployment_version).to eq "#{mtime.strftime('%Y-%m-%d %H:%M')} (deadbeef)"
      end
    end

    it 'reports an unknown version when there is nothing to derive it from' do
      Dir.mktmpdir do |dir|
        allow(Rails).to receive(:root).and_return(Pathname.new(dir))
        expect(helper.deployment_version).to eq I18n.t(:version_unknown)
      end
    end
  end

  describe '#update_param' do
    it 'updates a parameter in a simple URL' do
      url = 'https://example.com/path?foo=bar'
      result = helper.update_param(url, 'baz', 'qux')
      uri = Addressable::URI.parse(result)
      params = uri.query_values
      expect(params['foo']).to eq('bar')
      expect(params['baz']).to eq('qux')
    end

    it 'updates an existing parameter' do
      url = 'https://example.com/path?foo=bar&baz=old'
      result = helper.update_param(url, 'baz', 'new')
      uri = Addressable::URI.parse(result)
      params = uri.query_values
      expect(params['foo']).to eq('bar')
      expect(params['baz']).to eq('new')
    end

    it 'handles URLs without query parameters' do
      url = 'https://example.com/path'
      result = helper.update_param(url, 'foo', 'bar')
      expect(result).to eq('https://example.com/path?foo=bar')
    end

    it 'handles URLs with non-ASCII characters (Hebrew)' do
      # Test the exact case from the bug report: Hebrew letter פ
      # \xD7\xA4 is UTF-8 encoding for פ
      url = "https://benyehuda.org/dict/24412?page=112&to_letter=\xD7\xA4"
      result = helper.update_param(url, 'page', '113')

      # The result should have the page updated and preserve the Hebrew character
      expect(result).to include('page=113')
      expect(result).to include('to_letter=')
      # Check that the URL is valid and doesn't raise an error
      expect { URI.parse(result) }.not_to raise_error
    end

    it 'properly percent-encodes non-ASCII characters' do
      url = 'https://example.com/path?letter=א'
      result = helper.update_param(url, 'page', '1')

      # The Hebrew letter א should be percent-encoded
      expect(result).to include('page=1')
      expect(result).to include('letter=')
    end

    it 'handles multiple non-ASCII characters' do
      url = 'https://example.com/path?term=שלום&lang=he'
      result = helper.update_param(url, 'page', '2')

      expect(result).to include('page=2')
      expect(result).to include('term=')
      expect(result).to include('lang=he')
    end
  end

  # 'Pageless' authorities (e.g. 'anonymous', 'various authors') aren't real creators; a TOC page for
  # them would falsely suggest hundreds of works by one author, so they must never be linked to.
  describe '#authority_link' do
    let(:regular_authority) { create(:authority, name: 'Haim Nahman Bialik') }
    let(:pageless_authority) { create(:authority, name: 'anonymous', pageless: true) }

    it 'links to the TOC page of a regular authority' do
      result = helper.authority_link(regular_authority)
      expect(result).to have_css("a[href='#{authority_path(regular_authority.id)}']", text: 'Haim Nahman Bialik')
    end

    it 'renders the name of a pageless authority as plain text' do
      result = helper.authority_link(pageless_authority)
      expect(result).to eq 'anonymous'
      expect(result).not_to have_css('a')
    end

    it 'accepts an explicit link text for a regular authority' do
      result = helper.authority_link(regular_authority, '5 works')
      expect(result).to have_css('a', text: '5 works')
    end

    it 'renders the explicit text without a link for a pageless authority' do
      expect(helper.authority_link(pageless_authority, '5 works')).to eq '5 works'
    end

    it 'accepts a bare id' do
      expect(helper.authority_link(pageless_authority.id, 'anonymous')).to eq 'anonymous'
      expect(helper.authority_link(regular_authority.id, 'Bialik')).to have_css('a')
    end

    it 'passes html options through for a regular authority' do
      result = helper.authority_link(regular_authority, nil, target: '_blank')
      expect(result).to have_css("a[target='_blank']")
    end

    it 'escapes the name of a pageless authority' do
      evil = create(:authority, name: '<script>x</script>', pageless: true)
      expect(helper.authority_link(evil)).to eq '&lt;script&gt;x&lt;/script&gt;'
    end
  end

  describe '#link_to_authority' do
    let(:regular_authority) { create(:authority) }
    let(:pageless_authority) { create(:authority, pageless: true) }

    it 'wraps the block in a link for a regular authority' do
      result = helper.link_to_authority(regular_authority) { '<b>card</b>'.html_safe }
      expect(result).to have_css("a[href='#{authority_path(regular_authority.id)}'] b", text: 'card')
    end

    it 'wraps the block in a span for a pageless authority, preserving the markup' do
      result = helper.link_to_authority(pageless_authority) { '<b>card</b>'.html_safe }
      expect(result).to have_css('span b', text: 'card')
      expect(result).not_to have_css('a')
    end

    it 'keeps css classes but drops target on the span for a pageless authority' do
      result = helper.link_to_authority(pageless_authority, class: 'slide', target: '_blank') { 'x' }
      expect(result).to have_css('span.slide')
      expect(result).not_to have_css("[target='_blank']")
    end
  end

  describe '#role_options' do
    it 'offers every role, in presentation order' do
      expect(helper.role_options.map(&:last)).to eq(InvolvedAuthority::ROLES_PRESENTATION_ORDER)
    end

    it 'labels each role with its translated name' do
      expect(helper.role_options).to include([I18n.t('involved_authority.role.annotator'), 'annotator'])
    end

    it 'offers only the given roles, still in presentation order' do
      expect(helper.role_options(InvolvedAuthority::WORK_ROLES).map(&:last))
        .to eq(InvolvedAuthority::ROLES_PRESENTATION_ORDER - %w(translator))
    end

    it 'accepts symbols' do
      expect(helper.role_options(%i(translator author)).map(&:last)).to eq(%w(author translator))
    end
  end

  describe '#textify_role' do
    it 'returns the masculine form for a male annotator' do
      expect(helper.textify_role('annotator', 'male')).to eq(I18n.t(:annotator))
    end

    it 'returns the feminine form for a female annotator' do
      expect(helper.textify_role('annotator', 'female')).to eq(I18n.t(:annotator_f))
    end
  end
end
