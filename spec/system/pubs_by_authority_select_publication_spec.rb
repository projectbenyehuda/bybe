# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Selecting an existing publication in pubs_by_authority', :js, type: :system do
  let(:user) { create(:user, :bib_workshop) }
  let(:authority) { create(:authority, bib_done: false) }
  let!(:first_pub) { create(:publication, authority: authority, title: 'First Pub') }
  let!(:second_pub) { create(:publication, authority: authority, title: 'Second Pub') }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as(user)
  end

  it 'marks a clicked publication as selected, and moves the selection on a second click' do
    visit bib_pubs_by_authority_path(authority_id: authority.id)
    expect(page).to have_css("#pubs tr#pub#{second_pub.id}", wait: 10)

    find("tr#pub#{first_pub.id} td", match: :first).click
    expect(page).to have_css("tr#pub#{first_pub.id}.pub_selected")

    find("tr#pub#{second_pub.id} td", match: :first).click
    expect(page).to have_css("tr#pub#{second_pub.id}.pub_selected")
    expect(page).to have_no_css("tr#pub#{first_pub.id}.pub_selected")
    expect(page).to have_css('tr.pub_selected', count: 1)
  end

  describe 'adding a holding to the selected publication' do
    let(:bib_source) { create(:bib_source, source_type: :googlebooks) }
    let(:found_pub) do
      Gared::Publication.new(bib_source).tap do |pub|
        pub.title = 'Found In Catalog'
        pub.author_line = authority.name
        pub.publisher_line = 'Some Publisher'
        pub.pub_year = '1900'
        pub.language = 'heb'
        pub.source_id = ['gbook123']
        pub.scanned = false
        pub.add_holding(Gared::Holding.new.tap { |h| h.location = 'Shelf 1' })
      end
    end

    before do
      # Stand in for the external catalog so the search renders one source card without network access
      provider = instance_double(Gared::Googlebooks, query_publications_by_person: [found_pub])
      allow(Gared::Googlebooks).to receive(:new).and_return(provider)
    end

    it 'creates the holding under the selected publication and removes the source card' do
      visit bib_pubs_by_authority_path(authority_id: authority.id, q: authority.name, bib_source: bib_source.id)
      expect(page).to have_css("#pubs tr#pub#{second_pub.id}", wait: 10)
      expect(page).to have_css('#bibs .pub-card', text: 'Found In Catalog')

      find("tr#pub#{second_pub.id} td", match: :first).click
      expect(page).to have_css("tr#pub#{second_pub.id}.pub_selected")

      within('#bibs .pub-card', text: 'Found In Catalog') { click_button I18n.t(:add_holding) }

      expect(page).to have_no_css('#bibs .pub-card', text: 'Found In Catalog', wait: 10)
      expect(page).to have_css("tr#pub#{second_pub.id} ol li", count: 1)
      expect(second_pub.holdings.pluck(:source_id)).to eq(['https://books.google.co.il/books?id=gbook123'])
      expect(first_pub.holdings).to be_empty
    end
  end
end
