# frozen_string_literal: true

require 'rails_helper'

# Prev/next volume navigation shown on Collection#show when a 'volume' sits inside
# a 'volume_series'. The links are plain server-rendered anchors (no JS), so a
# rack_test system spec exercises them reliably.
describe 'Collection#show volume-series navigation' do
  # Each volume needs >= 2 manifestations, otherwise Collection#show redirects a
  # single-manifestation collection straight to that manifestation.
  def build_volume(title)
    Chewy.strategy(:atomic) do
      create(:collection, title: title, collection_type: :volume,
                          manifestations: create_list(:manifestation, 2, status: :published))
    end
  end

  let!(:vol1) { build_volume('Volume One') }
  let!(:vol2) { build_volume('Volume Two') }
  let!(:vol3) { build_volume('Volume Three') }

  let!(:series) do
    Chewy.strategy(:atomic) do
      create(:collection, title: 'The Series', collection_type: :volume_series,
                          included_collections: [vol1, vol2, vol3])
    end
  end

  after { Chewy.massacre }

  it 'shows prev, up (series) and next links for a middle volume' do
    visit collection_path(vol2)

    nav = find('.author-works-nav', wait: 10)
    within(nav) do
      expect(page).to have_link(href: collection_path(vol1))
      expect(page).to have_link(href: collection_path(vol3))
      expect(page).to have_link(href: collection_path(series))
      expect(page).to have_text(I18n.t(:to_previous_volume))
      expect(page).to have_text(I18n.t(:to_next_volume))
    end
  end

  it 'omits the prev link for the first volume' do
    visit collection_path(vol1)

    nav = find('.author-works-nav', wait: 10)
    within(nav) do
      expect(page).to have_link(href: collection_path(vol2))
      expect(page).to have_link(href: collection_path(series))
      expect(page).not_to have_text(I18n.t(:to_previous_volume))
    end
  end

  it 'omits the next link for the last volume' do
    visit collection_path(vol3)

    nav = find('.author-works-nav', wait: 10)
    within(nav) do
      expect(page).to have_link(href: collection_path(vol2))
      expect(page).not_to have_text(I18n.t(:to_next_volume))
    end
  end

  it 'shows no series navigation for a standalone volume' do
    standalone = build_volume('Standalone Volume')

    visit collection_path(standalone)

    expect(page).to have_css('.work-info-card', wait: 10)
    expect(page).not_to have_css('.author-works-nav')
  end
end
