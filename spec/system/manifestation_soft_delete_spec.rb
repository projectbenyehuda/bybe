# frozen_string_literal: true

require 'rails_helper'

describe 'Soft-deleting a Manifestation', :js, type: :system do
  let(:editor) { create(:user, :deletions) }
  let(:plain_editor) { create(:user, editor: true) }
  let(:catalog_editor) { create(:user, :edit_catalog) }
  let!(:manifestation) { create(:manifestation) }
  let!(:target) { create(:manifestation) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  context 'when an editor holding the deletions bit is reading the work' do
    before do
      login_as(editor)
      visit manifestation_path(id: manifestation.id)
    end

    it 'offers both ways of identifying the replacement work' do
      find('#soft-delete-btn a').click
      expect(page).to have_css('#softDeleteDlg', visible: :visible)
      expect(page).to have_content(I18n.t(:soft_delete_explanation))
      expect(page).to have_css('#soft_delete_autocomplete', visible: :visible)
      expect(page).to have_css('#soft_redirect_id', visible: :visible)
    end

    it 'soft-deletes the work and redirects future readers to the replacement' do
      find('#soft-delete-btn a').click
      expect(page).to have_css('#softDeleteDlg', visible: :visible)
      fill_in 'soft_redirect_id', with: target.id
      accept_confirm { find('#soft_delete_submit').click }

      expect(page).to have_content(I18n.t(:soft_delete_succeeded, id: target.id.to_s))
      expect(manifestation.reload).to be_deprecated

      visit manifestation_path(id: manifestation.id)
      expect(page).to have_current_path(manifestation_path(id: target.id))
      expect(page).to have_content(target.title)
    end
  end

  # jQuery UI appends the suggestion menu to <body>, outside the modal, so it lands in the root
  # stacking context and has to outrank `.modal` there or it is painted behind the dialog it was
  # opened from. See the `.ui-menu.ui-autocomplete.ui-front` rule in application.scss.
  context 'when picking the replacement work from the autocomplete inside the modal' do
    let!(:target) { create(:manifestation, title: 'Zamenhof Replacement Text') }

    before do
      import_and_await(ManifestationsAutocompleteIndex, [target])
      login_as(editor)
      visit manifestation_path(id: manifestation.id)
    end

    after do
      Chewy.massacre
    end

    it 'draws the suggestion menu above the modal rather than behind it' do
      find('#soft-delete-btn a').click
      expect(page).to have_css('#softDeleteDlg', visible: :visible)
      fill_in 'soft_delete_autocomplete', with: 'Zamenhof'
      expect(page).to have_css('ul.ui-autocomplete li', text: target.title, wait: 5)

      # Stacking order is not observable from the DOM tree, so ask the browser what it actually
      # paints at the centre of the menu: if the modal wins, that is a modal element, not the menu.
      topmost_is_the_menu = page.evaluate_script(<<~JS)
        (function () {
          var menu = document.querySelector('ul.ui-autocomplete');
          var box = menu.getBoundingClientRect();
          var painted = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
          return menu.contains(painted);
        })();
      JS
      expect(topmost_is_the_menu).to be true
    end

    it 'records the picked work as the redirect target' do
      find('#soft-delete-btn a').click
      expect(page).to have_css('#softDeleteDlg', visible: :visible)
      fill_in 'soft_delete_autocomplete', with: 'Zamenhof'
      find('ul.ui-autocomplete li', text: target.title, wait: 5).click

      field_opts = { type: 'hidden', with: target.id.to_s, visible: :all }
      expect(page).to have_field('soft_redirect_autocomplete_id', **field_opts)
    end
  end

  context 'when an editor lacks the deletions bit' do
    it 'does not offer the button' do
      login_as(plain_editor)
      visit manifestation_path(id: manifestation.id)
      expect(page).to have_content(manifestation.title)
      expect(page).to have_no_css('#soft-delete-btn')
    end
  end

  # edit_catalog used to be what gated this, so it is worth pinning down that it no longer does.
  context 'when an editor has edit_catalog but not the deletions bit' do
    it 'offers the other editor actions but not this one' do
      login_as(catalog_editor)
      visit manifestation_path(id: manifestation.id)
      expect(page).to have_css('#originating-task-btn')
      expect(page).to have_no_css('#soft-delete-btn')
    end
  end

  context 'when nobody is logged in' do
    it 'does not offer the button' do
      visit manifestation_path(id: manifestation.id)
      expect(page).to have_content(manifestation.title)
      expect(page).to have_no_css('#soft-delete-btn')
    end
  end

  describe 'undoing a soft-deletion from the backend show page' do
    # #show is reachable to editors holding either edit_catalog or deletions (so a deletions-only editor can
    # reach the undo button). A soft-deleted work has no other page an editor can reach it on, since
    # #read forwards even editors to the replacement.
    let(:deleter) { create(:user, :edit_catalog, :deletions) }

    before { SoftDeleteManifestation.call(manifestation, target) }

    it 'republishes the work and stops redirecting readers away from it' do
      login_as(deleter)
      visit manifestation_show_path(manifestation.id)
      expect(page).to have_css('#soft-delete-status')
      accept_confirm { find('#undo-soft-delete-btn').click }

      expect(page).to have_content(I18n.t(:undo_soft_delete_succeeded))
      expect(manifestation.reload).to be_published

      visit manifestation_path(id: manifestation.id)
      expect(page).to have_current_path(manifestation_path(id: manifestation.id))
      expect(page).to have_content(manifestation.title)
    end

    it 'is not offered to an editor without the deletions bit' do
      login_as(catalog_editor)
      visit manifestation_show_path(manifestation.id)
      expect(page).to have_css('#soft-delete-status')
      expect(page).to have_no_css('#undo-soft-delete-btn')
    end

    it 'is not offered on a work that is not soft-deleted' do
      login_as(deleter)
      visit manifestation_show_path(target.id)
      expect(page).to have_link(I18n.t(:soft_delete_work))
      expect(page).to have_no_css('#undo-soft-delete-btn')
    end
  end
end
