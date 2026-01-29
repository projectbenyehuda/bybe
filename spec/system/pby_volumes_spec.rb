# frozen_string_literal: true

require 'rails_helper'

describe 'PBY Volumes page' do
  let(:authority) { create(:authority, id: Authority::PBY_AUTHORITY_ID) }
  let!(:pby_volume1) do
    create(:collection, collection_type: 'volume', title: 'Project Ben-Yehuda Volume 1').tap do |vol|
      vol.involved_authorities.create!(authority: authority, role: 'editor')
    end
  end
  let!(:pby_volume2) do
    create(:collection, collection_type: 'volume', title: 'Project Ben-Yehuda Volume 2').tap do |vol|
      vol.involved_authorities.create!(authority: authority, role: 'editor')
    end
  end
  let!(:other_volume) { create(:collection, collection_type: 'volume', title: 'Other Volume') }

  describe 'browsing pby volumes' do
    it 'displays pby volumes list' do
      visit '/pby_volumes'

      expect(page).to have_content('Project Ben-Yehuda Volume 1')
      expect(page).to have_content('Project Ben-Yehuda Volume 2')
      expect(page).not_to have_content('Other Volume')
    end

    it 'displays header with title' do
      visit '/pby_volumes'

      expect(page).to have_css('.headline-1-v02')
    end

    it 'has links to collection show pages' do
      visit '/pby_volumes'

      expect(page).to have_link('Project Ben-Yehuda Volume 1', href: collection_path(pby_volume1))
      expect(page).to have_link('Project Ben-Yehuda Volume 2', href: collection_path(pby_volume2))
    end

    it 'displays volume count' do
      visit '/pby_volumes'

      # The count should be displayed somewhere on the page
      expect(page).to have_content('(2)')
    end
  end

  describe 'navigating from homepage', :js do
    it 'allows navigation to pby volumes from homepage link' do
      visit '/'

      # Click the link to pby volumes (it's in the "works" partial)
      # The link text is from i18n key :pby_publications
      click_link href: pby_volumes_path

      expect(page).to have_current_path(pby_volumes_path)
      expect(page).to have_content('Project Ben-Yehuda Volume 1')
    end
  end
end
