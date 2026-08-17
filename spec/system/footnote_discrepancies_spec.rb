# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Footnote discrepancy indicator', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    # System specs require stubbing at the controller level
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # rubocop:enable RSpec/AnyInstance
  end

  let(:user) { create(:user, :edit_catalog) }
  let(:manifestation) { create(:manifestation, status: :published, markdown: markdown) }

  context 'when references and bodies all match' do
    let(:markdown) { "טקסט עם הערה[^1]\n\n[^1]: גוף ההערה\n" }

    it 'shows no indicator' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('#markdown', wait: 5)
      expect(page).to have_no_css('.footnote-discrepancies')
    end
  end

  context 'when there is an orphan reference and an orphan body' do
    let(:markdown) { "טקסט עם הפניה[^1]\n\n[^2]: גוף ללא הפניה\n" }

    it 'shows a collapsed indicator that expands into the two lists on click' do
      visit manifestation_edit_path(manifestation)

      expect(page).to have_css('.footnote-discrepancies', wait: 5)
      expect(page).to have_content(I18n.t('footnote_discrepancies.indicator', count: 2))

      # the details start out collapsed
      expect(page).to have_no_content(I18n.t('footnote_discrepancies.orphan_references'))

      find('.footnote-discrepancies-toggle').click

      expect(page).to have_content(I18n.t('footnote_discrepancies.orphan_references'), wait: 5)
      expect(page).to have_content(I18n.t('footnote_discrepancies.orphan_bodies'))
      lists = all('.footnote-discrepancies-list')
      expect(lists.first).to have_content('[^1]')
      expect(lists.last).to have_content('[^2]')
    end

    it 'sits above the markdown and preview panes' do
      visit manifestation_edit_path(manifestation)
      expect(page).to have_css('.footnote-discrepancies', wait: 5)

      indicator_bottom = page.evaluate_script(
        "document.querySelector('.footnote-discrepancies').getBoundingClientRect().bottom"
      )
      markdown_top = page.evaluate_script(
        "document.querySelector('.markdown_container').getBoundingClientRect().top"
      )
      expect(indicator_bottom).to be <= markdown_top
    end
  end
end
