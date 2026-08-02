# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editor-only impressions count display', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:regular_user) { create(:user) }
  let(:editor) { create(:user, editor: true) }

  def login_as(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe 'Manifestation#read' do
    # Viewing the page itself bumps impressions_count by one before the view renders
    let!(:manifestation) { create(:manifestation, impressions_count: 1_234_567) }

    it 'shows the view count with thousands separators to editors' do
      login_as(editor)
      visit manifestation_path(id: manifestation.id)

      expect(page).to have_css('.impressions-count', text: '1,234,568', wait: 5)
      expect(page).to have_css('.impressions-count', text: I18n.t(:impressions_count))
    end

    it 'does not show the view count to non-editors' do
      login_as(regular_user)
      visit manifestation_path(id: manifestation.id)

      expect(page).to have_css('.headline-1-v02', wait: 5) # page rendered
      expect(page).not_to have_css('.impressions-count')
    end

    it 'does not show the view count to anonymous visitors' do
      visit manifestation_path(id: manifestation.id)

      expect(page).to have_css('.headline-1-v02', wait: 5) # page rendered
      expect(page).not_to have_css('.impressions-count')
    end
  end

  describe 'Authority#toc' do
    let!(:authority) { create(:authority, impressions_count: 7_654_321) }

    it 'shows the view count with thousands separators to editors' do
      login_as(editor)
      visit authority_path(authority)

      expect(page).to have_css('.impressions-count', text: '7,654,322', wait: 5)
      expect(page).to have_css('.impressions-count', text: I18n.t(:impressions_count))
    end

    it 'does not show the view count to non-editors' do
      login_as(regular_user)
      visit authority_path(authority)

      expect(page).to have_content(authority.name, wait: 5)
      expect(page).not_to have_css('.impressions-count')
    end

    it 'does not show the view count to anonymous visitors' do
      visit authority_path(authority)

      expect(page).to have_content(authority.name, wait: 5)
      expect(page).not_to have_css('.impressions-count')
    end
  end
end
