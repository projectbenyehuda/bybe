# frozen_string_literal: true

require 'rails_helper'

# Breadcrumbs on Manifestation#read. Since the move to Collection-based organization, the
# breadcrumbs show the full containing-collection ancestor chain (root-first) instead of the
# old trailing genre leaf: home -> authors -> author -> C -> B -> A, where sub-volume 'series'
# collections are shown but not clickable. Breadcrumbs are plain server-rendered markup, so a
# rack_test system spec exercises them reliably (no JS needed).
describe 'Manifestation#read breadcrumbs' do
  let!(:author) { create(:authority, toc: create(:toc)) }

  # A text inside series A, inside series B, inside volume C.
  let!(:text) do
    Chewy.strategy(:atomic) do
      create(:manifestation, author: author, orig_lang: 'he', status: :published)
    end
  end

  let!(:series_a) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Series A', collection_type: :series, manifestations: [text])
    end
  end

  let!(:series_b) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Series B', collection_type: :series, included_collections: [series_a])
    end
  end

  let!(:volume_c) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'Volume C', collection_type: :volume, included_collections: [series_b])
    end
  end

  after { Chewy.massacre }

  it 'shows the full collection ancestor chain, root-first, with series not clickable' do
    visit manifestation_path(text)

    within('#breadcrumbs') do
      # home -> authors -> author
      expect(page).to have_link(I18n.t(:authors), href: authors_path)
      expect(page).to have_link(author.name, href: authority_path(author))

      # ancestor chain: volume C (clickable) -> series B -> series A (both plain text)
      expect(page).to have_link('Volume C', href: collection_path(volume_c))
      expect(page).to have_text('Series B')
      expect(page).to have_text('Series A')
      expect(page).not_to have_link('Series B')
      expect(page).not_to have_link('Series A')

      # the old genre-leaf breadcrumb (linking into authors#toc with a genre param) is gone
      expect(page).not_to have_css("a[href*='genre=']")
    end
  end

  it 'orders the crumbs C before B before A (outermost first)' do
    visit manifestation_path(text)

    crumbs = all('#breadcrumbs .breadcrumbs-text').map(&:text)
    expect(crumbs.index('Volume C')).to be < crumbs.index('Series B')
    expect(crumbs.index('Series B')).to be < crumbs.index('Series A')
  end

  context 'when the text is not in any collection' do
    let!(:lone_text) do
      Chewy.strategy(:atomic) do
        create(:manifestation, author: author, orig_lang: 'he', status: :published)
      end
    end

    it 'shows only home -> authors -> author with no collection crumbs or genre leaf' do
      visit manifestation_path(lone_text)

      within('#breadcrumbs') do
        expect(page).to have_link(I18n.t(:authors), href: authors_path)
        expect(page).to have_link(author.name, href: authority_path(author))
        expect(page).not_to have_css("a[href*='/collections/']")
        expect(page).not_to have_css("a[href*='genre=']")
      end
    end
  end
end
