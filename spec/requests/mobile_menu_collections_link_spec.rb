# frozen_string_literal: true

require 'rails_helper'

# The desktop dropdown (#menu-works) has always offered "list all collections";
# the mobile sidenav (#menuMobile) was missing it, so mobile visitors had no way
# to reach the collections list from the menu.
RSpec.describe 'Mobile menu collections link', type: :request do
  around do |example|
    I18n.with_locale(:he) { example.run }
  end

  def mobile_menu
    menu = Nokogiri::HTML(response.body).at_css('#menuMobile')
    expect(menu).not_to be_nil, 'the mobile menu (#menuMobile) is missing from the page'
    menu
  end

  def collections_links
    mobile_menu.css("a[href='#{collections_browse_path}']")
  end

  before { get root_path }

  it 'links to the collections list from the mobile menu' do
    expect(response).to have_http_status(:ok)
    expect(collections_links).not_to be_empty, 'no link to the collections list in the mobile menu'
  end

  it 'labels the link the same way the desktop dropdown does' do
    expect(collections_links).not_to be_empty, 'no link to the collections list in the mobile menu'
    expect(collections_links.first.text).to include(I18n.t(:list_all_collections))
  end
end
