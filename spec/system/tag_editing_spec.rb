# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Tag Editing', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let(:tag) { create(:tag, status: :approved, name: 'Original Tag Name') }
  let!(:tag_name1) { tag.tag_names.first } # Created automatically
  let!(:tag_name2) { create(:tag_name, tag: tag, name: 'Alternative Name') }

  describe 'Edit links visibility' do
    context 'when user has moderate_tags permission' do
      before do
        login_as_moderator
      end

      it 'shows edit link in public tags browse view' do
        visit tags_browse_path

        expect(page).to have_link(I18n.t(:edit), href: edit_tag_path(tag))
      end

      it 'shows edit link in tag portal view' do
        visit tag_path(tag)

        expect(page).to have_link(I18n.t(:edit), href: edit_tag_path(tag))
      end

      it 'shows edit link in admin tag review for approved tags' do
        # tag_review requires tagging lock
        File.write('/tmp/tagging.lock', "#{@current_test_user.id}")
        visit tag_review_path(tag)

        expect(page).to have_content(I18n.t(:this_tag_is_already_approved))
        expect(page).to have_link(I18n.t(:edit_tag), href: edit_tag_path(tag))
      ensure
        File.delete('/tmp/tagging.lock') if File.exist?('/tmp/tagging.lock')
      end
    end

    context 'when user does not have moderate_tags permission' do
      let(:regular_user) { create(:user, editor: false) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(regular_user)
      end

      it 'does not show edit link in public tags browse view' do
        visit tags_browse_path

        expect(page).not_to have_link(I18n.t(:edit), href: edit_tag_path(tag))
      end

      it 'does not show edit link in tag portal view' do
        visit tag_path(tag)

        expect(page).not_to have_link(I18n.t(:edit), href: edit_tag_path(tag))
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'does not show edit link in public tags browse view' do
        visit tags_browse_path

        expect(page).not_to have_link(I18n.t(:edit))
      end
    end
  end

  describe 'Tag editing page' do
    before do
      login_as_moderator
    end

    it 'displays tag information and form fields' do
      visit edit_tag_path(tag)

      expect(page).to have_content("#{I18n.t(:edit_tag)}: #{tag.name}")
      expect(page).to have_field(I18n.t(:tag_name), with: tag.name)
      expect(page).to have_select(I18n.t(:status))
      expect(page).to have_content(I18n.t(:tag_names_aliases))
      expect(page).to have_content('Original Tag Name')
      expect(page).to have_content('Alternative Name')
    end

    it 'displays all TagName aliases' do
      visit edit_tag_path(tag)

      within('ul') do
        expect(page).to have_content(tag_name1.name)
        expect(page).to have_content(tag_name2.name)
      end
    end

    it 'shows remove button for non-sole TagNames' do
      visit edit_tag_path(tag)

      # Should have remove buttons since there are 2 TagNames
      expect(page).to have_button(I18n.t(:remove), count: 2)
    end

    it 'shows add TagName form' do
      visit edit_tag_path(tag)

      expect(page).to have_content(I18n.t(:add_tag_name_alias))
      expect(page).to have_field(I18n.t(:new_tag_name_placeholder))
      expect(page).to have_button(I18n.t(:add))
    end

    it 'shows merge and save buttons' do
      visit edit_tag_path(tag)

      expect(page).to have_button(I18n.t(:save_changes))
      expect(page).to have_content(I18n.t(:merge_tag))
      expect(page).to have_link(I18n.t(:back_to_moderation))
    end
  end

  describe 'Updating tag name', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'updates the tag name successfully' do
      fill_in I18n.t(:tag_name), with: 'Updated Tag Name'
      click_button I18n.t(:save_changes)

      # Wait for redirect and flash message
      expect(page).to have_content(I18n.t(:tag_updated), wait: 10)
      expect(tag.reload.name).to eq('Updated Tag Name')
      expect(tag.tag_names.first.name).to eq('Updated Tag Name')
    end

    it 'shows the updated name in the form' do
      fill_in I18n.t(:tag_name), with: 'New Name'
      click_button I18n.t(:save_changes)

      expect(page).to have_field(I18n.t(:tag_name), with: 'New Name')
    end
  end

  describe 'Updating tag status', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'updates the tag status successfully' do
      select I18n.t(:tag_status_escalated), from: I18n.t(:status)
      click_button I18n.t(:save_changes)

      expect(page).to have_content(I18n.t(:tag_updated))
      expect(tag.reload.status).to eq('escalated')
    end

    it 'can change status to pending' do
      select I18n.t(:tag_status_pending), from: I18n.t(:status)
      click_button I18n.t(:save_changes)

      # Wait for the update to complete
      expect(page).to have_content(I18n.t(:tag_updated), wait: 10)
      expect(tag.reload.status).to eq('pending')
    end

    it 'can change status to rejected' do
      select I18n.t(:tag_status_rejected), from: I18n.t(:status)
      click_button I18n.t(:save_changes)

      # Wait for the update to complete
      expect(page).to have_content(I18n.t(:tag_updated), wait: 10)
      expect(tag.reload.status).to eq('rejected')
    end
  end

  describe 'Adding TagName aliases', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'adds a new TagName alias successfully' do
      fill_in I18n.t(:new_tag_name_placeholder), with: 'New Alias'
      within('form[action*="add_tag_name"]') do
        click_button I18n.t(:add)
      end

      expect(page).to have_content(I18n.t(:tag_name_added))
      expect(page).to have_content('New Alias')
      expect(tag.tag_names.pluck(:name)).to include('New Alias')
    end

    it 'shows error when adding duplicate TagName' do
      existing_tag_name = create(:tag_name, name: 'Existing Name')

      fill_in I18n.t(:new_tag_name_placeholder), with: 'Existing Name'
      within('form[action*="add_tag_name"]') do
        click_button I18n.t(:add)
      end

      expect(page).to have_content(I18n.t(:tag_name_already_exists))
      expect(tag.tag_names.count).to eq(2) # Still only 2
    end

    it 'displays the new alias in the list' do
      fill_in I18n.t(:new_tag_name_placeholder), with: 'Third Alias'
      within('form[action*="add_tag_name"]') do
        click_button I18n.t(:add)
      end

      within('ul') do
        expect(page).to have_content('Third Alias')
      end
    end
  end

  describe 'Removing TagName aliases', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'removes a TagName alias successfully', skip: 'Confirmation dialog handling' do
      # Find the remove button for the second TagName
      within('li', text: 'Alternative Name') do
        accept_confirm(I18n.t(:confirm_remove_tag_name)) do
          click_button I18n.t(:remove)
        end
      end

      expect(page).to have_content(I18n.t(:tag_name_removed))
      expect(page).not_to have_content('Alternative Name')
      expect(tag.tag_names.count).to eq(1)
    end

    it 'does not show remove button when only one TagName remains' do
      # Remove the second TagName
      tag_name2.destroy
      tag.reload
      visit edit_tag_path(tag)

      # Should not have any remove buttons
      expect(page).not_to have_button(I18n.t(:remove))
    end

    it 'prevents removing the last TagName', skip: 'Confirmation dialog handling' do
      tag_name2.destroy
      tag.reload
      visit edit_tag_path(tag)

      # Try to remove via direct request (since button shouldn't be there)
      page.driver.submit :delete, remove_tag_name_path(tag_name1), {}

      visit edit_tag_path(tag)
      expect(page).to have_content(I18n.t(:cannot_remove_last_tag_name))
      expect(tag.tag_names.count).to eq(1)
    end
  end

  describe 'Permission requirements', :js do
    context 'when user lacks moderate_tags permission' do
      let(:regular_user) { create(:user, editor: false) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(regular_user)
      end

      it 'denies access to edit page' do
        visit edit_tag_path(tag)

        expect(page).to have_content(I18n.t(:not_an_editor))
        expect(current_path).not_to eq(edit_tag_path(tag))
      end
    end

    context 'when user is not logged in' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it 'denies access' do
        visit edit_tag_path(tag)

        # Should not be on the edit page
        expect(current_path).not_to eq(edit_tag_path(tag))
      end
    end
  end

  describe 'Complete editing workflow', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'allows full tag editing workflow' do
      # Update name
      fill_in I18n.t(:tag_name), with: 'Completely Updated Tag'

      # Update status
      select I18n.t(:tag_status_escalated), from: I18n.t(:status)

      # Save
      click_button I18n.t(:save_changes)

      expect(page).to have_content(I18n.t(:tag_updated))

      tag.reload
      expect(tag.name).to eq('Completely Updated Tag')
      expect(tag.status).to eq('escalated')
      expect(tag.tag_names.first.name).to eq('Completely Updated Tag')
    end

    it 'allows adding multiple aliases in sequence' do
      # Add first alias
      fill_in I18n.t(:new_tag_name_placeholder), with: 'Alias One'
      within('form[action*="add_tag_name"]') do
        click_button I18n.t(:add)
      end
      expect(page).to have_content('Alias One')

      # Add second alias
      fill_in I18n.t(:new_tag_name_placeholder), with: 'Alias Two'
      within('form[action*="add_tag_name"]') do
        click_button I18n.t(:add)
      end
      expect(page).to have_content('Alias Two')

      expect(tag.tag_names.count).to eq(4) # Original + Alternative + Alias One + Alias Two
    end
  end

  describe 'Navigation and back links', :js do
    before do
      login_as_moderator
      visit edit_tag_path(tag)
    end

    it 'has a back to moderation link' do
      click_link I18n.t(:back_to_moderation)

      expect(current_path).to eq(tag_moderation_path)
    end

    it 'stays on edit page after successful update' do
      fill_in I18n.t(:tag_name), with: 'New Name'
      click_button I18n.t(:save_changes)

      expect(current_path).to eq(edit_tag_path(tag))
    end
  end
end
