# frozen_string_literal: true

require 'rails_helper'

# Regression: the site-wide `.modal-content { background-color: transparent }` rule makes JS-built
# Bootstrap modals without their own inner card render as a bare backdrop with only buttons visible.
RSpec.describe 'Backend JS-built modals are opaque', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  def computed_style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  describe 'manage_toc "make collection" modal' do
    let(:toc) do
      create(:toc, toc: "## שירה\n\n### Some Volume\n\n* Some poem\n")
    end
    let(:author) { create(:authority, toc: toc) }

    before { login_as_catalog_editor }

    it 'renders an opaque dialog' do
      visit authors_manage_toc_path(author)
      find('.toc h3 .make-volume', match: :first).click
      expect(page).to have_css('#makeVolumeModal.show', visible: :visible, wait: 5)

      expect(computed_style('#makeVolumeModal .modal-content', 'backgroundColor')).to eq('rgb(255, 255, 255)')
    end
  end

  describe 'edit tag "merge tag" modal' do
    let(:tag) { create(:tag, status: :approved, name: 'Tag To Merge') }

    before do
      login_as_moderator
      mock_tagging_lock
    end

    after { cleanup_tagging_lock }

    # The loaded partial draws its own .by-popup-v02 card, so the transparent .modal-content is fine here.
    it 'renders an opaque popup card' do
      visit edit_tag_path(tag)
      find('.merge-btn').click
      expect(page).to have_css('#mergeTagModal.show', visible: :visible, wait: 5)
      expect(page).to have_css('#mergeTagModal #do_merge_tag', visible: :visible)

      expect(computed_style('#mergeTagModal .by-popup-v02', 'backgroundColor')).not_to eq('rgba(0, 0, 0, 0)')
    end
  end
end
