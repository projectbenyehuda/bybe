# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-author selection modal', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  before(:all) do
    clean_tables
    Chewy.strategy(:atomic) do
      # Minimal manifestations so the works page renders without ES errors
      create_list(:manifestation, 2, status: :published)
      ManifestationsIndex.reset!
    end

    # 30 authors fills the modal list and triggers viewport overflow without the fix
    create_list(:authority, 30)
  end

  after(:all) do
    clean_tables
  end

  it 'shows action buttons within the viewport without scrolling the modal overlay' do
    # Use a constrained desktop viewport height to reliably trigger the overflow
page.driver.browser.manage.window.resize_to(1280, 768)
visit works_path
    # Switch to author-name mode to reveal the multiselect link
    find('.opt_authorname', wait: 5).click

    # Open the multi-author dialog
find('[data-target="#authorsDlg"]', wait: 5).click

expect(page).to have_css('#authorsDlg.show', wait: 10)

    # Action buttons must sit fully inside the viewport; they must never be
    # pushed below the fold by an overflowing modal dialog.
    in_viewport = page.evaluate_script(<<~JS)
      (function() {
        var el = document.querySelector('#authorsDlg .bottom-left-buttons');
        if (!el) { return false; }
        var rect = el.getBoundingClientRect();
        return rect.bottom <= window.innerHeight && rect.top >= 0;
      })()
    JS

    expect(in_viewport).to be true
  end

  it 'does not scroll the modal overlay itself' do
page.driver.browser.manage.window.resize_to(1280, 768)
visit works_path
    find('.opt_authorname', wait: 5).click
find('[data-target="#authorsDlg"]', wait: 5).click

expect(page).to have_css('#authorsDlg.show', wait: 10)

    # The modal overlay must compute overflow:hidden so it never gets a scrollbar
    overflow = page.evaluate_script(
      "window.getComputedStyle(document.getElementById('authorsDlg')).overflow"
    )

    expect(overflow).to eq('hidden')
  end
end
