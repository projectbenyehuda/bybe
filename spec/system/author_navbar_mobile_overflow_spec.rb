# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author page mobile sticky navbar overflow', :js, type: :system do
  let!(:author) { create(:authority, name: 'Test Author') }
  let!(:collection) { create(:collection, title: 'Test Collection') }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Test Work', status: :published, author: author)
    end
    create(:involved_authority, authority: author, item: collection, role: 'editor')
    page.driver.browser.manage.window.resize_to(375, 667)
  end

  after { Chewy.massacre }

  describe 'at mobile viewport width (375px)' do
    it 'sets overflow-x: hidden on the nav col to clip any child overflow' do
      visit authority_path(author)
      expect(page).to have_css('.author-side-nav-col', wait: 5)

      overflow_x = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('.author-side-nav-col')).overflowX"
      )

      expect(overflow_x).to eq('hidden')
    end

    it 'prevents the content col from wrapping past the spacer via flex-wrap: nowrap' do
      visit authority_path(author)
      expect(page).to have_css('.author-page-content .col-12 > .row', wait: 5)

      flex_wrap = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('.author-page-content .col-12 > .row')).flexWrap"
      )

      expect(flex_wrap).to eq('nowrap')
    end
  end
end
