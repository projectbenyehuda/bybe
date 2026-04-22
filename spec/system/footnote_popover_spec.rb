# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Footnote popovers', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:markdown_content) do
    <<~MARKDOWN
      This is a text with a footnote reference.[^1]

      [^1]: This is the footnote body.
    MARKDOWN
  end

  let!(:manifestation) do
    m = create(:manifestation, markdown: markdown_content, status: :published)
    m.recalc_heading_lines
    m.save!
    m
  end

  def footnote_anchor
    find('a.footnote[data-toggle="popover"]', visible: :all)
  end

  describe 'clicking a footnote reference' do
    it 'shows the popover without navigating to the footnote body' do
      visit manifestation_path(manifestation)

      initial_url = current_url
      footnote_anchor.click

      expect(page).to have_css('.popover', visible: true, wait: 5)
      expect(current_url).to eq(initial_url)
    end

    it 'shows the footnote body text in the popover' do
      visit manifestation_path(manifestation)

      footnote_anchor.click

      expect(page).to have_css('.popover', visible: true, wait: 5)
      expect(find('.popover')).to have_content('This is the footnote body.')
    end

    it 'shows a link to the footnote body in the popover' do
      visit manifestation_path(manifestation)

      footnote_anchor.click

      expect(page).to have_css('.popover', visible: true, wait: 5)
      within('.popover') do
        expect(page).to have_link('להערת השוליים בסוף הטקסט')
      end
    end

    it 'shows a [x] close link in the popover' do
      visit manifestation_path(manifestation)

      footnote_anchor.click

      expect(page).to have_css('.popover', visible: true, wait: 5)
      within('.popover') do
        expect(page).to have_link('[x]')
      end
    end

    it 'dismisses the popover when the [x] link is clicked' do
      visit manifestation_path(manifestation)

      footnote_anchor.click
      expect(page).to have_css('.popover', visible: true, wait: 5)

      within('.popover') { find('.fn-popover-close').click }

      expect(page).not_to have_css('.popover', visible: true, wait: 5)
    end
  end
end
