# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Manifestation search highlighting', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # Scroll position thresholds for validation
  # These values account for header height and provide buffer for test reliability
  MINIMAL_SCROLL_THRESHOLD = 300  # Max scroll if we stayed at top (header + margin)
  SIGNIFICANT_SCROLL_THRESHOLD = 100  # Min scroll if we scrolled to first match

  let(:markdown_content) do
    <<~MARKDOWN
      ## Chapter 1

      This is some sample text with the word sample appearing multiple times.
      Here is another paragraph with more content.

      ## Chapter 2

      Another section with different content and more text.
      The word sample appears here as well.
    MARKDOWN
  end

  let!(:manifestation_with_title_match) do
    Chewy.strategy(:atomic) do
      create(:manifestation,
             title: 'Sample Work Title',
             markdown: markdown_content,
             status: :published)
    end
  end

  let!(:manifestation_without_title_match) do
    Chewy.strategy(:atomic) do
      create(:manifestation,
             title: 'Different Work Title',
             markdown: markdown_content,
             status: :published)
    end
  end

  before do
    # Ensure heading lines are calculated
    manifestation_with_title_match.recalc_heading_lines
    manifestation_with_title_match.save!

    manifestation_without_title_match.recalc_heading_lines
    manifestation_without_title_match.save!
  end

  after do
    Chewy.massacre
  end

  def current_scroll_position
    page.evaluate_script('window.pageYOffset || document.documentElement.scrollTop')
  end

  describe 'search highlighting behavior' do
    context 'when search term matches the title' do
      it 'does not auto-scroll to first occurrence in text' do
        visit manifestation_path(manifestation_with_title_match, q: 'sample')

        # Wait for page to load and search highlighting to be applied
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Allow time for any potential scroll to happen
        sleep 0.5

        # Check that we are still at the top of the page (not scrolled to first match in text)
        # The scroll position should be minimal since we shouldn't have scrolled to the first text match
        expect(current_scroll_position).to be < MINIMAL_SCROLL_THRESHOLD
      end

      it 'still highlights all occurrences of the search term' do
        visit manifestation_path(manifestation_with_title_match, q: 'sample')

        # Search controls should be visible
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Multiple matches should be found (at least 2 in the text content)
        total_matches = page.find('#total-matches').text.to_i
        expect(total_matches).to be >= 2
      end
    end

    context 'when search term does not match the title' do
      it 'auto-scrolls to first occurrence in text as usual' do
        visit manifestation_path(manifestation_without_title_match, q: 'sample')

        # Wait for page to load and search highlighting to be applied
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Allow time for scroll to happen
        sleep 0.5

        # Check that we have scrolled down (away from top of page)
        # We expect scroll position to be significant since we should have scrolled to first match
        expect(current_scroll_position).to be > SIGNIFICANT_SCROLL_THRESHOLD
      end

      it 'highlights all occurrences of the search term' do
        visit manifestation_path(manifestation_without_title_match, q: 'sample')

        # Search controls should be visible
        expect(page).to have_css('#search-highlight-controls', visible: :visible)

        # Multiple matches should be found
        total_matches = page.find('#total-matches').text.to_i
        expect(total_matches).to be >= 2
      end
    end

    context 'when search term partially matches the title' do
      it 'does not auto-scroll when title contains the search term' do
        visit manifestation_path(manifestation_with_title_match, q: 'Sample')

        # Wait for page to load
        expect(page).to have_css('#search-highlight-controls', visible: :visible)
        sleep 0.5

        # Should not scroll since "Sample" is in the title "Sample Work Title"
        expect(current_scroll_position).to be < MINIMAL_SCROLL_THRESHOLD
      end
    end

    context 'when there is no search query' do
      it 'does not show search controls or highlight anything' do
        visit manifestation_path(manifestation_with_title_match)

        # Search controls should not be visible
        expect(page).to have_no_css('#search-highlight-controls', visible: :visible)
      end
    end
  end
end
