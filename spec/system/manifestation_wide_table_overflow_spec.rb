# frozen_string_literal: true

require 'rails_helper'

# Regression test for a text whose markdown contains a wide table (e.g. work 25626, the
# "Habima repertoire" table). MarkdownToHtml wraps every <table> in a
# `<div style="overflow-x:auto">` so wide tables scroll instead of stretching the page, but
# .work-content is a `flex: 1` item of the flex container .work-area, and a flex item's
# automatic minimum size is its min-content width. That made the column expand to the table's
# min-content width, pushing it past the surrounding .by-card-v02 and laying the ordinary body
# paragraphs out at the inflated width, so they spilled over the card edge into the gutter.
describe 'Manifestation#read with a wide table', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  # Eight columns. The cells hold single unbreakable words, so each column's min-content width
  # is the full word and the table's min-content width comfortably exceeds the text column.
  let(:wide_table_markdown) do
    header = (1..8).map { |i| "כותרתעמודהארוכהמאד#{i}" }
    rows = (1..6).map { |r| (1..8).map { |c| "תוכןתאארוךומאודרחב#{r}#{c}" } }
    [
      'פסקה רגילה של טקסט לפני הטבלה.',
      '',
      "| #{header.join(' | ')} |",
      "| #{(['---'] * 8).join(' | ')} |",
      *rows.map { |row| "| #{row.join(' | ')} |" },
      '',
      'פסקה רגילה של טקסט אחרי הטבלה, שאמורה להישאר בתוך גבולות הכרטיס.'
    ].join("\n")
  end

  let!(:text) do
    Chewy.strategy(:atomic) do
      create(:manifestation, orig_lang: 'he', status: :published, markdown: wide_table_markdown)
    end
  end

  after { Chewy.massacre }

  # Returns [work_content_left, work_content_right, card_left, card_right, body_scroll_width,
  #          viewport_width] as measured in the browser.
  def layout_metrics
    page.evaluate_script(<<~JS)
      (function () {
        var wc = document.querySelector('.work-content').getBoundingClientRect();
        var card = document.querySelector('.by-card-v02.proofable').getBoundingClientRect();
        return [wc.left, wc.right, card.left, card.right,
                document.body.scrollWidth, document.documentElement.clientWidth];
      })()
    JS
  end

  # 700px sits in the band where the blowout was worst: wide enough that .work-side-color is
  # still displayed (BY_styles_Max639.css hides it and gives .work-content width: 100% below
  # 640px), but too narrow to fit the table's min-content width.
  [[700, 900], [1400, 900]].each do |width, height|
    it "keeps the text column inside its card at #{width}px" do
      page.driver.browser.manage.window.resize_to(width, height)
      visit manifestation_path(text)
      expect(page).to have_css('#actualtext table')

      wc_left, wc_right, card_left, card_right, body_scroll_width, viewport_width = layout_metrics

      # The text column must not stick out of the card on either side (it overflowed to the
      # left, the far side in this RTL layout).
      expect(wc_left).to be >= card_left - 1
      expect(wc_right).to be <= card_right + 1

      # ...and the page as a whole must not gain a horizontal scrollbar.
      expect(body_scroll_width).to be <= viewport_width + 1
    end
  end

  it 'still lets the wide table itself scroll horizontally' do
    page.driver.browser.manage.window.resize_to(700, 900)
    visit manifestation_path(text)
    expect(page).to have_css('#actualtext table')

    scrollable = page.evaluate_script(<<~JS)
      (function () {
        var wrap = document.querySelector('#actualtext div[style*="overflow-x"]');
        return wrap ? wrap.scrollWidth > wrap.clientWidth : null;
      })()
    JS
    expect(scrollable).to be true
  end
end
