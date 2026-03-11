# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TOC paratext collapse', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:authority) { create(:authority) }

  describe 'long paratext (> 80 non-whitespace chars)' do
    let(:multi_line_markdown) do
      "## Introduction Title\n\nThis paragraph provides enough context to exceed the eighty non-whitespace character threshold."
    end

    let!(:collection) do
      create(:collection, collection_type: 'other', authors: [authority],
                          markdown_placeholders: [multi_line_markdown])
    end

    it 'shows a plain-text truncated preview with a show-more toggle, no raw markdown' do
      visit authority_path(authority)

      expect(page).to have_css('span.paratext-preview', visible: :visible, wait: 5)
      # Preview is plain text — no HTML tags, no raw ## markers
      expect(page).to have_css('span.paratext-preview', text: 'Introduction Title')
      expect(page).not_to have_content('##')
      expect(page).not_to have_css('span.paratext-preview h2')
      expect(page).to have_css('button.paratext-toggle', text: I18n.t(:show_more))
    end

    it 'hides the full content initially' do
      visit authority_path(authority)

      expect(page).to have_css('[id^="paratext_collapse_"]', visible: :hidden, wait: 5)
    end

    it 'hides the preview and shows full HTML content on expand' do
      visit authority_path(authority)

      find('.paratext-toggle', wait: 5).click

      expect(page).to have_css('[id^="paratext_collapse_"].show', wait: 5)
      # Full rendered HTML is visible
      expect(page).to have_css('h2', text: 'Introduction Title', wait: 5)
      # Preview text is hidden to avoid duplication
      expect(page).to have_css('span.paratext-preview', visible: :hidden, wait: 5)
      expect(page).to have_css('.paratext-toggle', text: I18n.t(:show_less), wait: 5)
    end

    it 'restores the preview and hides full content on collapse' do
      visit authority_path(authority)

      find('.paratext-toggle', wait: 5).click
      expect(page).to have_css('[id^="paratext_collapse_"].show', wait: 5)

      find('.paratext-toggle').click
      expect(page).to have_css('[id^="paratext_collapse_"]', visible: :hidden, wait: 5)
      expect(page).to have_css('span.paratext-preview', visible: :visible, wait: 5)
      expect(page).to have_css('.paratext-toggle', text: I18n.t(:show_more), wait: 5)
    end
  end

  describe 'single rendered paragraph' do
    it 'does not collapse a single-sentence paragraph' do
      create(:collection, collection_type: 'other', authors: [authority],
                          markdown_placeholders: ['A brief note about this collection.'])

      visit authority_path(authority)

      expect(page).to have_content('A brief note about this collection.', wait: 5)
      expect(page).not_to have_css('.paratext-preview')
      expect(page).not_to have_css('.paratext-toggle')
    end

    # Threshold is 80 non-whitespace chars; short content never collapses regardless of newlines
    it 'does not collapse short content with multiple raw markdown lines' do
      create(:collection, collection_type: 'other', authors: [authority],
                          markdown_placeholders: ["Line one\nLine two\nLine three"])

      visit authority_path(authority)

      expect(page).to have_content('Line one', wait: 5)
      expect(page).not_to have_css('.paratext-preview')
      expect(page).not_to have_css('.paratext-toggle')
    end
  end
end
