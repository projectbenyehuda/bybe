# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mass Update Tool', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_catalog_editor
  end

  let!(:manifestation) { create(:manifestation, title: 'Test Manifestation') }
  let!(:collection)    { create(:collection, title: 'Test Collection', collection_type: :volume) }

  # Adds a record to the selection list via the "By ID" tab, then waits for it to appear.
  def add_record_by_id(type_label, id)
    select type_label, from: 'direct_record_type'
    fill_in 'direct_id', with: id.to_s
    click_button I18n.t('admin.mass_update.add_button'), match: :first
    # Wait for the record to appear in the list (Capybara auto-waits)
    find('#records-list', text: "##{id}", wait: 5)
  end

  # Adds a field_update change to the changes list.
  # field_name is the internal key (e.g. 'title'); field_label is the localized label shown in the dropdown.
  def add_field_update_change(record_type_label, field_name, value, record_type_key: nil)
    select I18n.t('admin.mass_update.change_kind_field_update'), from: 'change_kind'
    select record_type_label, from: 'field_record_type'
    field_label = record_type_key ? I18n.t("admin.mass_update.fields.#{record_type_key}.#{field_name}") : field_name
    select field_label, from: 'field-name-select'
    fill_in 'field_value', with: value
    click_button I18n.t('admin.mass_update.add_change_button')
    find('#changes-list', text: field_label, wait: 5)
  end

  describe 'page load' do
    it 'renders the page title and both sections' do
      visit admin_mass_update_path
      expect(page).to have_content(I18n.t('admin.mass_update.new.title'), wait: 5)
      expect(page).to have_content(I18n.t('admin.mass_update.section_records'))
      expect(page).to have_content(I18n.t('admin.mass_update.section_changes'))
    end
  end

  describe 'adding a record by ID' do
    before { visit admin_mass_update_path }

    it 'adds a Manifestation to the list' do
      add_record_by_id(I18n.t('admin.mass_update.record_type_manifestation'), manifestation.id)
      expect(page).to have_content("Manifestation ##{manifestation.id}")
      expect(page).not_to have_content(I18n.t('admin.mass_update.no_records_in_list'))
    end
  end

  describe 'adding a field_update change' do
    before do
      visit admin_mass_update_path
      add_record_by_id(I18n.t('admin.mass_update.record_type_manifestation'), manifestation.id)
    end

    it 'adds a change to the changes list' do
      add_field_update_change(I18n.t('admin.mass_update.record_type_manifestation'),
                              'title', 'Updated Title', record_type_key: 'manifestation')
      expect(page).to have_content(I18n.t('admin.mass_update.fields.manifestation.title') + ' = Updated Title')
    end
  end

  describe 'applying changes' do
    before do
      visit admin_mass_update_path
      add_record_by_id(I18n.t('admin.mass_update.record_type_manifestation'), manifestation.id)
      add_field_update_change(I18n.t('admin.mass_update.record_type_manifestation'), 'title', 'Mass Updated Title')
    end

    it 'applies the changes and shows results' do
      page.accept_confirm do
        click_button I18n.t('admin.mass_update.apply_button')
      end
      expect(page).to have_content(I18n.t('admin.mass_update.results_title'), wait: 10)
      expect(page).to have_content(I18n.t('admin.mass_update.result_ok'), wait: 5)
      expect(manifestation.reload.title).to eq('Mass Updated Title')
    end
  end

  describe 'saving and loading selections' do
    before do
      visit admin_mass_update_path
      add_record_by_id(I18n.t('admin.mass_update.record_type_manifestation'), manifestation.id)
    end

    it 'saves a private selection' do
      fill_in 'new_selection_name', with: 'My Private Selection'
      click_button I18n.t('admin.mass_update.save_private_button')
      expect(page).to have_content(I18n.t('admin.saved_selections.save_success'), wait: 5)
      expect(SavedSelection.where(name: 'My Private Selection', shared: false)).to exist
    end

    it 'saves a shared selection' do
      fill_in 'new_selection_name', with: 'Shared Selection'
      click_button I18n.t('admin.mass_update.save_shared_button')
      expect(page).to have_content(I18n.t('admin.saved_selections.save_success'), wait: 5)
      expect(SavedSelection.where(name: 'Shared Selection', shared: true)).to exist
    end

    context 'when a selection exists in the DB' do
      let!(:saved_selection) do
        sel = SavedSelection.create!(name: 'Existing Selection', user: create_catalog_editor, shared: false)
        sel.saved_selection_items.create!(item_type: 'Manifestation', item_id: manifestation.id)
        sel
      end

      it 'shows the selection in the dropdown and loads it' do
        visit admin_mass_update_path
        # The dropdown is populated via AJAX on page load
        expect(page).to have_select('saved-selections-dropdown',
                                    with_options: ['Existing Selection (1)'], wait: 5)
        select 'Existing Selection (1)', from: 'saved-selections-dropdown'
        click_button I18n.t('admin.mass_update.load_selection_button')
        expect(page).to have_content("Manifestation ##{manifestation.id}", wait: 5)
      end
    end
  end

  describe 'collection expansion options' do
    let!(:sub_manifestation) { create(:manifestation, title: 'Sub Manifestation') }
    let!(:_collection_item) do
      create(:collection_item, collection: collection, item: sub_manifestation,
                               seqno: 1, item_type: 'Manifestation')
    end

    before { visit admin_mass_update_path }

    it 'shows expansion options when adding a collection by ID' do
      add_record_by_id(I18n.t('admin.mass_update.record_type_collection'), collection.id)
      expect(page).to have_content(I18n.t('admin.mass_update.collection_expand_label'), wait: 5)
    end

    it 'adds only the collection when collection_only is selected' do
      add_record_by_id(I18n.t('admin.mass_update.record_type_collection'), collection.id)
      choose I18n.t('admin.mass_update.collection_expand_collection_only')
      click_button I18n.t('admin.mass_update.add_button'), id: 'confirm-add-collection-btn'
      expect(page).to have_content("Collection ##{collection.id}", wait: 5)
      expect(page).not_to have_content("Manifestation ##{sub_manifestation.id}")
    end
  end

  describe 'removing a record from the list' do
    before do
      visit admin_mass_update_path
      add_record_by_id(I18n.t('admin.mass_update.record_type_manifestation'), manifestation.id)
    end

    it 'removes a record when clicking the remove button' do
      within('#records-list') do
        click_button I18n.t('admin.mass_update.remove_button')
      end
      expect(page).to have_content(I18n.t('admin.mass_update.no_records_in_list'), wait: 5)
    end
  end
end
