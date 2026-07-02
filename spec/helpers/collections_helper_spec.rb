# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionsHelper, type: :helper do
  describe '#url_for_collection_item' do
    it 'returns nil when the item is a series sub-collection (not clickable)' do
      series = create(:collection, collection_type: :series)
      ci = build(:collection_item, item: series)
      expect(helper.url_for_collection_item(ci)).to be_nil
    end

    it 'returns nil when the item is a periodical_issue sub-collection (not clickable)' do
      issue = create(:collection, collection_type: :periodical_issue)
      ci = build(:collection_item, item: issue)
      expect(helper.url_for_collection_item(ci)).to be_nil
    end

    it 'returns a URL for a volume sub-collection (still clickable)' do
      volume = create(:collection, collection_type: :volume)
      ci = build(:collection_item, item: volume)
      expect(helper.url_for_collection_item(ci)).to eq(url_for(volume))
    end

    it 'returns a URL for a manifestation item' do
      manifestation = create(:manifestation)
      ci = build(:collection_item, item: manifestation)
      expect(helper.url_for_collection_item(ci)).to eq(url_for(manifestation))
    end
  end

  describe '#collection_search_result_path' do
    let(:query) { 'search term' }

    it 'links a series result to its volume parent plus an anchor to the sub-collection' do
      series = create(:collection, collection_type: :series)
      volume = create(:collection, collection_type: :volume, included_collections: [series])
      result = Struct.new(:id, :collection_type).new(series.id, 'series')

      expect(helper.collection_search_result_path(result, query))
        .to eq(collection_path(volume.id, q: query, anchor: "collection_#{series.id}"))
    end

    it 'links a series result with no volume/issue ancestor to its own show page' do
      series = create(:collection, collection_type: :series)
      result = Struct.new(:id, :collection_type).new(series.id, 'series')

      expect(helper.collection_search_result_path(result, query))
        .to eq(collection_path(series.id, q: query))
    end

    it 'links a non-series result to its own show page' do
      volume = create(:collection, collection_type: :volume)
      result = Struct.new(:id, :collection_type).new(volume.id, 'volume')

      expect(helper.collection_search_result_path(result, query))
        .to eq(collection_path(volume.id, q: query))
    end
  end

  describe '#collection_up_link_path' do
    it 'links a series to its volume parent plus an anchor to the sub-collection' do
      series = create(:collection, collection_type: :series)
      volume = create(:collection, collection_type: :volume, included_collections: [series])

      expect(helper.collection_up_link_path(series))
        .to eq(collection_path(volume.id, anchor: "collection_#{series.id}"))
    end

    it 'bubbles up to the nearest volume/issue ancestor for a nested series' do
      inner = create(:collection, collection_type: :series)
      outer = create(:collection, collection_type: :series, included_collections: [inner])
      volume = create(:collection, collection_type: :volume, included_collections: [outer])

      expect(helper.collection_up_link_path(inner))
        .to eq(collection_path(volume.id, anchor: "collection_#{inner.id}"))
    end

    it 'links a series with no volume/issue ancestor to its own show page' do
      series = create(:collection, collection_type: :series)

      expect(helper.collection_up_link_path(series)).to eq(collection_path(series))
    end

    it 'links a volume collection to its own show page' do
      volume = create(:collection, collection_type: :volume)

      expect(helper.collection_up_link_path(volume)).to eq(collection_path(volume))
    end
  end

  describe '#convert_internal_links_to_relative' do
    let(:base_url) { 'https://example.com' }

    context 'when html contains absolute links to the same domain' do
      it 'converts absolute URLs to relative paths' do
        html = '<a href="https://example.com/path/to/page">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path/to/page"')
      end

      it 'preserves query strings' do
        html = '<a href="https://example.com/path?param=value">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path?param=value"')
      end

      it 'preserves fragments' do
        html = '<a href="https://example.com/path#section">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path#section"')
      end

      it 'preserves query strings and fragments together' do
        html = '<a href="https://example.com/path?param=value#section">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path?param=value#section"')
      end

      it 'converts URLs with no path to root path' do
        html = '<a href="https://example.com">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/"')
      end

      it 'converts URLs with no path but with query string' do
        html = '<a href="https://example.com?query=value">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/?query=value"')
      end

      it 'converts URLs with no path but with fragment' do
        html = '<a href="https://example.com#section">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/#section"')
      end

      it 'preserves target attribute on internal links' do
        html = '<a href="https://example.com/path" target="_blank">Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path"')
        expect(result).to include('target="_blank"')
      end

      it 'preserves target attribute on root path links' do
        html = '<a href="https://example.com" target="_blank">Home</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/"')
        expect(result).to include('target="_blank"')
      end

      it 'removes target attribute for same-page anchor links when current_path matches' do
        html = '<a href="https://example.com/current-page#section" target="_blank">Section</a>'
        result = helper.convert_internal_links_to_relative(base_url, html, '/current-page')
        expect(result).to include('href="/current-page#section"')
        expect(result).not_to include('target=')
      end

      it 'removes target attribute for same-page anchor links at the root path' do
        html = '<a href="https://example.com#section" target="_blank">Section</a>'
        result = helper.convert_internal_links_to_relative(base_url, html, '/')
        expect(result).to include('href="/#section"')
        expect(result).not_to include('target=')
      end

      it 'preserves target attribute for links to other pages with fragments' do
        html = '<a href="https://example.com/other-page#section" target="_blank">Section</a>'
        result = helper.convert_internal_links_to_relative(base_url, html, '/current-page')
        expect(result).to include('href="/other-page#section"')
        expect(result).to include('target="_blank"')
      end

      it 'preserves target attribute for same-path links without fragments' do
        html = '<a href="https://example.com/current-page" target="_blank">Page</a>'
        result = helper.convert_internal_links_to_relative(base_url, html, '/current-page')
        expect(result).to include('href="/current-page"')
        expect(result).to include('target="_blank"')
      end
    end

    context 'when html contains external links' do
      it 'does not modify links to different domains' do
        html = '<a href="https://other-domain.com/path">External Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="https://other-domain.com/path"')
      end

      it 'does not modify links with different schemes' do
        html = '<a href="http://example.com/path">HTTP Link</a>'
        result = helper.convert_internal_links_to_relative('https://example.com', html)
        expect(result).to include('href="http://example.com/path"')
      end

      it 'preserves target attribute on external links' do
        html = '<a href="https://other-domain.com/path" target="_blank">External Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="https://other-domain.com/path"')
        expect(result).to include('target="_blank"')
      end
    end

    context 'when html contains relative links' do
      it 'does not modify already relative links' do
        html = '<a href="/path/to/page">Relative Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/path/to/page"')
      end

      it 'does not modify fragment-only links' do
        html = '<a href="#section">Fragment Link</a>'
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="#section"')
      end
    end

    context 'when html contains multiple links' do
      it 'converts only internal absolute links' do
        html = <<~HTML
          <a href="https://example.com/internal1">Internal 1</a>
          <a href="https://other.com/external">External</a>
          <a href="https://example.com/internal2?q=test">Internal 2</a>
          <a href="/already-relative">Relative</a>
        HTML
        result = helper.convert_internal_links_to_relative(base_url, html)
        expect(result).to include('href="/internal1"')
        expect(result).to include('href="/internal2?q=test"')
        expect(result).to include('href="https://other.com/external"')
        expect(result).to include('href="/already-relative"')
      end
    end

    context 'when html contains malformed links' do
      it 'skips malformed URIs without errors' do
        html = '<a href="not a valid uri">Invalid</a>'
        expect { helper.convert_internal_links_to_relative(base_url, html) }.not_to raise_error
      end
    end

    context 'when html or base_url is blank' do
      it 'returns the original html when html is blank' do
        result = helper.convert_internal_links_to_relative(base_url, '')
        expect(result).to eq('')
      end

      it 'returns the original html when html is nil' do
        result = helper.convert_internal_links_to_relative(base_url, nil)
        expect(result).to be_nil
      end

      it 'returns the original html when base_url is blank' do
        html = '<a href="https://example.com/path">Link</a>'
        result = helper.convert_internal_links_to_relative('', html)
        expect(result).to eq(html)
      end

      it 'returns the original html when base_url is malformed' do
        html = '<a href="https://example.com/path">Link</a>'
        malformed_base = 'not a valid url at all'
        result = helper.convert_internal_links_to_relative(malformed_base, html)
        expect(result).to eq(html)
      end
    end

    context 'when base_url has a trailing slash' do
      it 'normalizes the base_url correctly' do
        html = '<a href="https://example.com/path">Link</a>'
        result = helper.convert_internal_links_to_relative('https://example.com/', html)
        expect(result).to include('href="/path"')
      end
    end
  end
end
