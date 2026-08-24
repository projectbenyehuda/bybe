# frozen_string_literal: true

require 'rails_helper'

describe 'Soft-deleting a Manifestation', :js, type: :system do
  let(:editor) { create(:user, :edit_catalog) }
  let(:plain_editor) { create(:user, editor: true) }
  let!(:manifestation) { create(:manifestation) }
  let!(:target) { create(:manifestation) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  context 'when an edit_catalog editor is reading the work' do
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

  context 'when an editor lacks the edit_catalog bit' do
    it 'does not offer the button' do
      login_as(plain_editor)
      visit manifestation_path(id: manifestation.id)
      expect(page).to have_content(manifestation.title)
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
end
