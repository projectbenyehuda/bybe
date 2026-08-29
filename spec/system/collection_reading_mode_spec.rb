# frozen_string_literal: true

require 'rails_helper'

# Collection#show used to render the reading-mode button as a bare <button href="#">, which is
# inert, and omitted it altogether from the mobile icon row. These specs guard both entry points
# and the reading-mode page they lead to.
RSpec.describe 'Collection reading mode', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  after { Chewy.massacre }

  # long enough that the reading-mode page is actually scrollable
  def long_body(label)
    Array.new(40) { |i| "#{label}, paragraph #{i + 1}." }.join("\n\n")
  end

  let!(:m1) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'First Text', markdown: long_body('Body of the first text'),
                             status: :published)
    end
  end

  let!(:m2) do
    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Second Text', markdown: long_body('Body of the second text'),
                             status: :published)
    end
  end

  let!(:collection) do
    Chewy.strategy(:atomic) do
      col = create(:collection, title: 'Readable Collection', collection_type: :volume)
      create(:collection_item, collection: col, item: m1, seqno: 1)
      create(:collection_item, collection: col, item: m2, seqno: 2)
      col
    end
  end

  context 'when on a desktop viewport' do
    before { resize_window(1400, 900) }

    it 'reaches reading mode by clicking the reading-mode button' do
      visit collection_path(collection)
      expect(page).to have_css('.work-page-top-icons-desktop .reading-mode-btn-v02', wait: 10)

      find('.work-page-top-icons-desktop .reading-mode-btn-v02').click

      expect(page).to have_current_path(collection_readmode_path(collection), wait: 10)
      expect(page).to have_css('.reading-mode .rm-control-panel', visible: :visible, wait: 10)
      expect(page).to have_content('Body of the first text, paragraph 1.')
      # the site chrome is gone in reading mode
      expect(page).to have_no_css('header')
    end

    it 'scrolls to the chosen item and offers a way back to the collection page' do
      visit collection_readmode_path(collection)
      expect(page).to have_css('select#collitem', wait: 10)

      find('select#collitem').select('Second Text')
      expect(wait_until_scrolled(wait: 10)).to be > 0

      find('.rm-control-panel a.collapse-expand-icon').click
      expect(page).to have_current_path(collection_path(collection), wait: 10)
    end
  end

  context 'when on a mobile viewport' do
    before { resize_window(375, 812) }

    it 'shows a reading-mode icon button that leads to reading mode' do
      visit collection_path(collection)
      expect(page).to have_css('.work-page-top-icons-mobile .reading-mode-icon-btn-v02',
                               visible: :visible, wait: 10)

      find('.work-page-top-icons-mobile .reading-mode-icon-btn-v02').click

      expect(page).to have_current_path(collection_readmode_path(collection), wait: 10)
      expect(page).to have_css('.reading-mode .rm-control-panel-mobile', visible: :visible, wait: 10)
    end
  end
end
