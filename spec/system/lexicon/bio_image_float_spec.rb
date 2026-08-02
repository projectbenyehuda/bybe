# frozen_string_literal: true

require 'rails_helper'

# Images embedded in a migrated biography used to sit on a line of their own, leaving a tall
# empty band of vertical space beside them. They must float so the biography text wraps around.
RSpec.describe 'Biography image float', :js, type: :system do
  # 1x1 transparent GIF, so the image loads deterministically; the width/height attributes
  # (as in the migrated entries) give it a real box.
  let(:pixel) { 'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==' }

  let(:paragraph) { (['ביוגרפיה של אדם כלשהו, טקסט ארוך דיו כדי לעטוף את התמונה.'] * 8).join(' ') }

  let(:bio) do
    <<~HTML
      <img src="#{pixel}" data-align="left" data-hspace="10" width="200" height="200" />

      <p>#{paragraph}</p>

      <p>#{paragraph}</p>
    HTML
  end

  let(:person) { create(:lex_person, bio: bio) }

  # Distance from the top of the first paragraph to the bottom of the floated image: negative
  # (paragraph starts above the image's bottom edge) means the text runs alongside the image.
  def paragraph_top_minus_image_bottom(container_selector)
    page.evaluate_script(<<~JS)
      (function() {
        var container = document.querySelector('#{container_selector}');
        var img = container.querySelector('img[data-align]');
        var para = container.querySelector('p');
        return para.getBoundingClientRect().top - img.getBoundingClientRect().bottom;
      })()
    JS
  end

  before { skip 'WebDriver not available or misconfigured' unless webdriver_available? }

  describe 'on the public entry page' do
    let!(:entry) { create(:lex_entry, :person, title: 'Test Person', lex_item: person, status: :published) }

    before { visit lexicon_entry_path(entry) }

    it 'floats the image so the biography text wraps around it' do
      expect(page).to have_css('#lexicon-biography img[data-align="left"]')

      # the paragraphs must be *inside* the container the float rules are scoped to
      expect(page).to have_css('#lexicon-biography p', count: 2)

      float = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#lexicon-biography img[data-align]')).float"
      )
      expect(float).to eq 'left'
      expect(paragraph_top_minus_image_bottom('#lexicon-biography')).to be < 0
    end
  end

  describe 'in the migration verification workbench' do
    let!(:entry) { create(:lex_entry, :person, title: 'Test Person', lex_item: person, status: :draft) }

    before do
      login_as_lexicon_editor
      entry.start_verification!('test@example.com')
      visit lexicon_verification_path(entry)
    end

    it 'floats the image so the biography text wraps around it' do
      expect(page).to have_css('#section-bio .bio-content img[data-align="left"]')

      float = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#section-bio .bio-content img[data-align]')).float"
      )
      expect(float).to eq 'left'
      expect(paragraph_top_minus_image_bottom('#section-bio .bio-content')).to be < 0
    end
  end
end
