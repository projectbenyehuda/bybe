# frozen_string_literal: true

require 'rails_helper'

# The desktop item navigator (#collitem_dropdown in shared/_collection_top) is hidden on narrow
# viewports, which left periodicals with no way to jump to a specific issue on mobile. A second
# dropdown at the bottom of the metadata card fills that gap, on mobile only.
describe 'Periodical issue dropdown on mobile', :js, :narrow_viewport, type: :system do
  let(:body) { (['מילה ' * 40] * 30).join("\n\n") }

  let!(:periodical) do
    periodical = create(:collection, title: 'My Periodical: A Magazine', collection_type: :periodical)
    [1, 2].each do |n|
      issue = create(:collection, title: "My Periodical – Issue #{n}", collection_type: :periodical_issue)
      create(:collection_item, collection: issue, seqno: 1,
                               item: create(:manifestation, title: "Text #{n}", markdown: body))
      create(:collection_item, collection: periodical, item: issue, seqno: n)
    end
    periodical
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  context 'with a mobile viewport' do
    before do
      resize_window(390, 844)
      visit collection_path(periodical)
    end

    it 'shows the issue dropdown at the bottom of the metadata card' do
      within('.work-info-card') do
        expect(page).to have_css('#collitem_dropdown_mobile', visible: :visible)
        options = all('#collitem_dropdown_mobile option').map(&:text)
        expect(options).to include('Issue 1', 'Issue 2')
        expect(options.join(' ')).not_to include('My Periodical')
      end
      expect(page).to have_css('#collitem_dropdown', visible: :hidden)
    end

    it 'scrolls to the selected issue' do
      select 'Issue 2', from: 'collitem_dropdown_mobile'
      expect(wait_until_scrolled(wait: 10)).to be > 0
    end
  end

  context 'with a desktop viewport' do
    before do
      resize_window(1400, 900)
      visit collection_path(periodical)
    end

    it 'shows only the desktop dropdown' do
      expect(page).to have_css('#collitem_dropdown', visible: :visible)
      expect(page).to have_css('#collitem_dropdown_mobile', visible: :hidden)
    end
  end

  context 'with a non-periodical collection' do
    let(:volume) { create(:collection, collection_type: :volume) }

    before do
      [1, 2].each do |n|
        create(:collection_item, collection: volume, seqno: n, item: create(:manifestation, title: "Chapter #{n}"))
      end
      resize_window(390, 844)
      visit collection_path(volume)
    end

    it 'does not add the mobile dropdown' do
      expect(page).to have_content('Chapter 1')
      expect(page).to have_no_css('#collitem_dropdown_mobile', visible: :all)
    end
  end
end
