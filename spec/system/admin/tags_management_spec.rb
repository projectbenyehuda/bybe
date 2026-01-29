# frozen_string_literal: true

require 'rails_helper'

describe 'Admin Tags Management' do
  let(:tag) { create(:tag, status: :approved, name: 'Original Tag Name') }
  let!(:primary_tag_name) { tag.tag_names.first } # Created automatically by callback
  let!(:alternative_tag_name) { create(:tag_name, tag: tag, name: 'Alternative Tag Name') }

  describe 'Making a TagName the primary name', :js do
    before do
      login_as_moderator
      visit edit_admin_tag_path(tag)
    end

    it 'changes the tag primary name when clicking make primary button' do
      # Verify we're on the edit page
      expect(page).to have_content(I18n.t('admin.tags.edit.title'))

      # Verify the current primary name is shown
      within('li', text: 'Original Tag Name') do
        expect(page).to have_content(I18n.t('admin.tags.form.primary_alias'))
      end

      # Verify the alternative name has a make primary button
      within('li', text: 'Alternative Tag Name') do
        expect(page).to have_button(I18n.t('admin.tags.form.make_primary'))
      end

      # Click the make primary button for the alternative name
      within('li', text: 'Alternative Tag Name') do
        click_button I18n.t('admin.tags.form.make_primary')
      end

      # Wait for redirect and success message
      expect(page).to have_content(I18n.t('admin.tags.primary_alias_changed',
                                          old: 'Original Tag Name',
                                          new: 'Alternative Tag Name'),
                                   wait: 10)

      # Verify the tag was updated in the database
      tag.reload
      expect(tag.name).to eq('Alternative Tag Name')

      # Verify the UI reflects the change
      within('li', text: 'Alternative Tag Name') do
        expect(page).to have_content(I18n.t('admin.tags.form.primary_alias'))
        expect(page).not_to have_button(I18n.t('admin.tags.form.make_primary'))
      end

      # Verify the old primary name now has a make primary button
      within('li', text: 'Original Tag Name') do
        expect(page).not_to have_content(I18n.t('admin.tags.form.primary_alias'))
        expect(page).to have_button(I18n.t('admin.tags.form.make_primary'))
      end
    end

    it 'maintains all tag_names after changing primary' do
      initial_count = tag.tag_names.count

      within('li', text: 'Alternative Tag Name') do
        click_button I18n.t('admin.tags.form.make_primary')
      end

      expect(page).to have_content(I18n.t('admin.tags.primary_alias_changed',
                                          old: 'Original Tag Name',
                                          new: 'Alternative Tag Name'),
                                   wait: 10)

      # Verify no tag_names were deleted
      expect(tag.tag_names.count).to eq(initial_count)

      # Verify both names still exist
      expect(tag.tag_names.pluck(:name)).to contain_exactly('Original Tag Name', 'Alternative Tag Name')
    end

    it 'persists the name change across page reloads' do
      within('li', text: 'Alternative Tag Name') do
        click_button I18n.t('admin.tags.form.make_primary')
      end

      # Wait for the change to complete
      expect(page).to have_content(I18n.t('admin.tags.primary_alias_changed',
                                          old: 'Original Tag Name',
                                          new: 'Alternative Tag Name'),
                                   wait: 10)

      # Reload the page
      visit edit_admin_tag_path(tag)

      # Verify the change persisted
      within('li', text: 'Alternative Tag Name') do
        expect(page).to have_content(I18n.t('admin.tags.form.primary_alias'))
      end

      # Verify in database
      fresh_tag = Tag.find(tag.id)
      expect(fresh_tag.name).to eq('Alternative Tag Name')
    end
  end

  describe 'Removing TagName aliases', :js do
    before do
      login_as_moderator
      visit edit_admin_tag_path(tag)
    end

    it 'shows delete button for non-primary aliases' do
      within('li', text: 'Alternative Tag Name') do
        expect(page).to have_button(I18n.t('admin.tags.form.delete_alias'))
      end
    end

    it 'does not show delete button for the primary alias' do
      within('li', text: 'Original Tag Name') do
        expect(page).not_to have_button(I18n.t('admin.tags.form.delete_alias'))
      end
    end
  end
end
