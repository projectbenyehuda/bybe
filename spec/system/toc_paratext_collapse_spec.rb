# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TOC paratext collapse', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:authority) { create(:authority) }

  describe 'multi-line paratext' do
    # Use a heading as the first line so we can verify it is rendered as HTML, not raw markdown
    let(:multi_line_markdown) do
      "## Introduction Title\n\nFirst paragraph body.\n\nSecond paragraph body."
    end

    let!(:collection) do
      create(:collection, collection_type: 'other', authors: [authority],
                          markdown_placeholders: [multi_line_markdown])
    end

    it 'renders the first line as HTML inside a preview div with a show-more toggle' do
      visit authority_path(authority)

      expect(page).to have_css('.paratext-preview', wait: 5)
      within('.paratext-preview') do
        # First line is rendered as an h2, not raw markdown (no '##' visible)
        expect(page).to have_css('h2', text: 'Introduction Title')
        expect(page).not_to have_content('##')
        expect(page).to have_css('button.paratext-toggle', text: I18n.t(:show_more))
      end
    end

    it 'hides the full content initially' do
      visit authority_path(authority)

      expect(page).to have_css('[id^="paratext_collapse_"]', visible: :hidden, wait: 5)
    end

    it 'expands the full content and updates toggle to show-less on click' do
      visit authority_path(authority)

      expect(page).to have_css('.paratext-toggle', text: I18n.t(:show_more), wait: 5)
      find('.paratext-toggle').click

      # Wait for animation to complete
      expect(page).to have_css('[id^="paratext_collapse_"].show', wait: 5)
      expect(page).to have_content('First paragraph body.', wait: 5)
      expect(page).to have_content('Second paragraph body.', wait: 5)
      expect(page).to have_css('.paratext-toggle', text: I18n.t(:show_less), wait: 5)
    end

    it 'collapses again on a second click and restores the show-more label' do
      visit authority_path(authority)

      find('.paratext-toggle', wait: 5).click
      # Wait for the open animation to fully complete (Bootstrap ignores clicks during 'collapsing')
      expect(page).to have_css('[id^="paratext_collapse_"].show', wait: 5)

      find('.paratext-toggle').click
      expect(page).to have_css('[id^="paratext_collapse_"]', visible: :hidden, wait: 5)
      expect(page).to have_css('.paratext-toggle', text: I18n.t(:show_more), wait: 5)
    end
  end

  describe 'single-line paratext' do
    let!(:collection) do
      create(:collection, collection_type: 'other', authors: [authority],
                          markdown_placeholders: ['A brief note about this collection.'])
    end

    it 'renders the paratext inline without a collapse widget' do
      visit authority_path(authority)

      expect(page).to have_content('A brief note about this collection.', wait: 5)
      expect(page).not_to have_css('.paratext-preview')
      expect(page).not_to have_css('.paratext-toggle')
    end
  end
end
