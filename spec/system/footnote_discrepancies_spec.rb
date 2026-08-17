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

  context 'when the offending line is far down a long buffer' do
    # the orphan reference sits on line 150, well past the bottom of the textarea
    let(:orphan_line) { 150 }
    let(:markdown) do
      lines = Array.new(200) { |i| "שורה מספר #{i + 1} ובה די והותר טקסט כדי לגלוש לשורה הבאה" }
      lines[orphan_line - 1] = 'שורה עם הפניה יתומה[^99]'
      lines.join("\n")
    end
    # every preceding line, newlines included
    let(:expected_offset) { markdown.lines[0, orphan_line - 1].sum(&:length) }

    def caret_position
      page.evaluate_script(
        "[document.querySelector('#markdown').selectionStart, document.querySelector('#markdown').selectionEnd]"
      )
    end

    def scroll_metrics
      top, height, visible = page.evaluate_script(
        '(function(el) { return [el.scrollTop, el.scrollHeight, el.clientHeight]; })' \
        "(document.querySelector('#markdown'))"
      )
      { top: top, height: height, visible: visible }
    end

    # Capybara's finders wait, so reaching the link is enough to know the page has settled.
    def line_link
      find('a.js-goto-markdown-line', text: orphan_line.to_s, wait: 5)
    end

    before do
      visit manifestation_edit_path(manifestation)
      find('.footnote-discrepancies-toggle', wait: 5).click
    end

    it 'places the caret at the start of that line when the number is clicked' do
      expect(caret_position).to eq([0, 0])

      line_link.click

      expect(caret_position).to eq([expected_offset, expected_offset])
      expect(page.evaluate_script("document.querySelector('#markdown').value")[expected_offset, 5])
        .to eq('שורה ')
    end

    it 'scrolls the textarea so the line is on screen' do
      expect(scroll_metrics[:top]).to eq(0)

      line_link.click

      metrics = scroll_metrics
      # All 200 lines are near-identical in length, so line 150 starts ~149/200 of the way
      # down the content. Derived from the buffer rather than from the code under test.
      line_top = metrics[:height] * (orphan_line - 1) / 200.0
      expect(metrics[:top]).to be < line_top
      expect(line_top).to be < metrics[:top] + metrics[:visible]
      # and it is not merely that the whole buffer fits on screen
      expect(metrics[:height]).to be > (metrics[:visible] * 2)
    end

    it 'jumps when the reported row is clicked anywhere, not just on the number' do
      # click the row's own text, well clear of the line-number link
      find('li.js-goto-markdown-line', text: orphan_line.to_s).find('bdi').click

      expect(caret_position).to eq([expected_offset, expected_offset])
    end
  end

  context 'when the same reference is orphaned on more than one line' do
    let(:markdown) { "ראשונה[^5]\nשנייה\nשלישית[^5]\n" }

    before do
      visit manifestation_edit_path(manifestation)
      find('.footnote-discrepancies-toggle', wait: 5).click
    end

    def caret_start
      page.evaluate_script("document.querySelector('#markdown').selectionStart")
    end

    it 'jumps to the first line when the row is clicked' do
      find('li.js-goto-markdown-line').find('bdi').click

      expect(caret_start).to eq(0)
    end

    it 'jumps to the clicked line number rather than the first one' do
      find('a.js-goto-markdown-line', text: '3').click

      expect(caret_start).to eq("ראשונה[^5]\nשנייה\n".length)
    end
  end

  # The click handler lives in shared/_markdown_utils, which is scoped to a container and a
  # textarea id that differ per screen. This one is also injected by AJAX, so it exercises
  # the case where the handler is bound to freshly rendered markup.
  context 'when on the ingestible texts tab, whose textarea has a different id' do
    let!(:ingestible) { create(:ingestible, :with_buffers) }

    before do
      ingestible.texts[0] = IngestibleText.new(
        'title' => 'כותרת', 'content' => "שורה ראשונה\nשורה עם הפניה יתומה[^7]\n"
      )
      ingestible.save!
      visit edit_ingestible_path(ingestible, text_index: 0)
    end

    it "places the caret at the start of the line in that screen's own textarea" do
      find('.footnote-discrepancies-toggle', wait: 10).click

      find('a.js-goto-markdown-line', text: '2', wait: 5).click

      caret = page.evaluate_script("document.querySelector('#ingestible_text_content').selectionStart")
      expect(caret).to eq("שורה ראשונה\n".length)
    end
  end
end
