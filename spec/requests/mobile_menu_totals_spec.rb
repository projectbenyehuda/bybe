# frozen_string_literal: true

require 'rails_helper'

# The mobile sidenav header used to report Authority.cached_toc_count -- a count of authorities with a
# legacy, hand-written Toc record. Now that the project has migrated away from manual TOCs, that count
# no longer means anything, and it disagreed with the figure the desktop menu shows. Both now use
# Authority.cached_count: published authorities that have a page of their own.
RSpec.describe 'Mobile menu totals', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  def mobile_totals_text
    totals = Nokogiri::HTML(response.body).at_css('.mobile-menu-top')
    expect(totals).not_to be_nil, 'the mobile menu totals (.mobile-menu-top) are missing from the page'
    totals.text
  end

  before do
    clean_tables
    Rails.cache.delete('au_published_count')
  end

  it 'reports the same authorities count the desktop menu uses' do
    create_list(:authority, 3)
    get root_path

    expect(response).to have_http_status(:ok)
    expect(mobile_totals_text).to include(
      I18n.t(:mobile_totals, authors: Authority.cached_count, works: Manifestation.cached_count)
    )
    expect(Authority.cached_count).to eq 3
  end

  it 'does not count unpublished or pageless authorities' do
    create_list(:authority, 2)
    create(:authority, status: :unpublished)
    create(:authority, pageless: true)
    get root_path

    expect(Authority.cached_count).to eq 2
    expect(mobile_totals_text).to include(
      I18n.t(:mobile_totals, authors: 2, works: Manifestation.cached_count)
    )
  end
end
