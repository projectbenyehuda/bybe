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
    visit bib_pubs_by_authority_path(authority_id: authority.id)
  end

  it 'marks a clicked publication as selected, and moves the selection on a second click' do
    expect(page).to have_css("#pubs tr#pub#{second_pub.id}", wait: 10)
    find("tr#pub#{first_pub.id} td", match: :first).click
    expect(page).to have_css("tr#pub#{first_pub.id}.pub_selected")

    find("tr#pub#{second_pub.id} td", match: :first).click
    expect(page).to have_css("tr#pub#{second_pub.id}.pub_selected")
    expect(page).to have_no_css("tr#pub#{first_pub.id}.pub_selected")
    expect(page).to have_css('tr.pub_selected', count: 1)
  end
end
