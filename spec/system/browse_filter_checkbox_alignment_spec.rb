# frozen_string_literal: true

require 'rails_helper'

# Regression test for the filter panes' option lists. Labels are inline-block
# site-wide, so before the fix a label too wide for the remainder of its line
# dropped whole to the next line, stranding its checkbox alone above it (and the
# CSS columns of .nested-list could split the pair too). Each checkbox must stay
# on the same line as, and immediately to the right of (RTL), its own label.
describe 'Browse filter checkbox alignment', :js do
  # Widths that keep the desktop two-column filter pane but progressively
  # squeeze it, which is what makes the longer Hebrew labels wrap.
  def window_widths
    [1400, 1200, 1100, 1000]
  end

  # Text of every option row whose checkbox is not on the same line as the first
  # line of its own label, or has drifted away from it horizontally.
  def misaligned_rows
    page.evaluate_script(<<~JS)
      (function () {
        return Array.prototype.slice.call(
          document.querySelectorAll('#filters_panel .filter-checkbox')
        ).filter(function (row) {
          var box = row.querySelector('input[type=checkbox]').getBoundingClientRect();
          var label = row.querySelector('label').getBoundingClientRect();
          var sharedHeight = Math.min(box.bottom, label.bottom) - Math.max(box.top, label.top);
          // at least half the checkbox must sit on the label's first line, and
          // in RTL the checkbox must be to the right of the label text
          return sharedHeight < 9 || box.left < label.right - 2;
        }).map(function (row) {
          return row.textContent.trim().replace(/\\s+/g, ' ');
        });
      })()
    JS
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      create(:manifestation, author: create(:authority, gender: 'female'))
      create(:manifestation, author: create(:authority, gender: 'male'))
    end
  end

  after do
    Chewy.massacre
  end

  shared_examples 'keeps every checkbox with its label' do |path_helper|
    it "keeps each checkbox next to its label at every width on #{path_helper}", :aggregate_failures do
      visit send(path_helper)
      expect(page).to have_css('#filters_panel .filter-checkbox')

      window_widths.each do |width|
        page.driver.browser.manage.window.resize_to(width, 900)

        expect(misaligned_rows).to eq([]), "checkboxes detached from their labels at #{width}px wide"
      end
    end
  end

  it_behaves_like 'keeps every checkbox with its label', :works_path
  it_behaves_like 'keeps every checkbox with its label', :authors_path
  it_behaves_like 'keeps every checkbox with its label', :collections_path
end
