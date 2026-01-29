# frozen_string_literal: true

require 'rails_helper'

describe 'Download modal', :js do
  let(:work) { create(:work) }
  let(:expression) { create(:expression, work: work) }
  let(:manifestation) do
    create(:manifestation,
           expression: expression,
           title: 'Test Manifestation',
           markdown: "# Test\n\nContent here")
  end

  before do
    manifestation # ensure it exists
  end

  it 'works correctly on repeated uses without page reload' do
    visit manifestation_path(manifestation)

    # First download attempt - click the download icon
    find('a.download[data-target="#downloadDlg"]').click
    expect(page).to have_selector('#downloadDlg', visible: true)

    # Select format and submit
    within '#downloadDlg' do
      choose 'format_pdf'
      click_button I18n.t(:download)
    end

    # Modal should close (Capybara will wait for it to disappear)
    expect(page).to have_no_selector('#downloadDlg', visible: true)

    # Second download attempt (without page reload)
    find('a.download[data-target="#downloadDlg"]').click
    expect(page).to have_selector('#downloadDlg', visible: true)

    # Select format and submit again
    within '#downloadDlg' do
      choose 'format_html'
      click_button I18n.t(:download)
    end

    # Modal should close again (Capybara will wait for it to disappear)
    expect(page).to have_no_selector('#downloadDlg', visible: true)

    # The test passes if we get here without errors or hanging
  end

  it 'works correctly for collections' do
    collection = create(:collection, title: 'Test Collection')
    create(:collection_item, collection: collection, item: manifestation, seqno: 1)

    visit collection_path(collection)

    # First download attempt - find download button by data-target
    find('[data-target="#downloadDlg"]').click
    expect(page).to have_selector('#downloadDlg', visible: true)

    # Select format and submit
    within '#downloadDlg' do
      choose 'format_epub'
      click_button I18n.t(:download)
    end

    # Modal should close (Capybara will wait for it to disappear)
    expect(page).to have_no_selector('#downloadDlg', visible: true)

    # Second download attempt
    find('[data-target="#downloadDlg"]').click
    expect(page).to have_selector('#downloadDlg', visible: true)

    # The download button should still be enabled
    within '#downloadDlg' do
      expect(page).to have_button(I18n.t(:download), disabled: false)
      choose 'format_pdf'
      click_button I18n.t(:download)
    end

    # Modal should close again (Capybara will wait for it to disappear)
    expect(page).to have_no_selector('#downloadDlg', visible: true)
  end
end
