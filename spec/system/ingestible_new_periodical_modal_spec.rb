# frozen_string_literal: true

require 'rails_helper'

# Regression: the site-wide `.modal-content { background-color: transparent }` rule made the
# JS-built "create new periodical" modal render as a bare backdrop with only its buttons visible.
RSpec.describe 'Ingestible "create new periodical" modal', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_catalog_editor
  end

  def open_new_periodical_modal
    visit new_ingestible_path
    begin
      find('#change_volume', wait: 5).click
    rescue Capybara::ElementNotFound
      # Volume details already visible
    end
    find('#create_new_periodical').click
    expect(page).to have_css('#newPeriodicalModal.show', visible: :visible, wait: 5)
  end

  it 'renders an opaque dialog with visible input fields' do
    open_new_periodical_modal

    background = page.evaluate_script(
      "getComputedStyle(document.querySelector('#newPeriodicalModal .modal-content')).backgroundColor"
    )
    expect(background).to eq('rgb(255, 255, 255)')

    %w(#new_periodical_title #new_issue_title).each do |selector|
      border_width = page.evaluate_script(
        "getComputedStyle(document.querySelector('#{selector}')).borderTopWidth"
      )
      expect(border_width).not_to eq('0px')
    end
  end

  it 'creates the periodical and its first issue from the dialog' do
    open_new_periodical_modal

    within('#newPeriodicalModal') do
      fill_in 'periodical_title', with: 'Test Periodical'
      fill_in 'issue_title', with: 'Issue 1'
      find('#newPeriodicalOkBtn').click
    end

    expect(page).to have_no_css('#newPeriodicalModal', wait: 5)
    expect(page).to have_select('ingestible_periodical_id', selected: 'Test Periodical', wait: 5)
    expect(page).to have_select('periodical_issues', selected: 'Issue 1', wait: 5)
    expect(Collection.find_by(title: 'Test Periodical', collection_type: :periodical)).to be_present
  end
end
