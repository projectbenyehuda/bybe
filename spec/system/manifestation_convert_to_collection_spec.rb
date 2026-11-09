# frozen_string_literal: true

require 'rails_helper'

describe 'Converting a Manifestation into a Collection', :js, type: :system do
  let!(:manifestation) do
    create(:manifestation, title: 'Poems', markdown: "## First poem\nOne.\n\n## Second poem\nTwo.\n")
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  context 'when the editor holds the batch_editing bit' do
    before do
      login_as(create_batch_editor)
      visit manifestation_path(id: manifestation.id)
    end

    it 'splits the text into a collection from the read view' do
      find('#convert-to-collection-btn a').click
      expect(page).to have_css('#convertToCollectionDlg', visible: :visible)
      expect(page).to have_content(I18n.t(:convert_to_collection_explanation))
      select I18n.t('activerecord.attributes.collection.collection_types.volume'), from: 'convert_collection_type'
      accept_confirm { find('#convert_to_collection_submit').click }

      expect(page).to have_content(I18n.t(:convert_to_collection_succeeded))
      collection = Collection.find_by!(title: 'Poems')
      expect(page).to have_current_path(collection_path(collection))
      expect(collection).to be_volume
      expect(page).to have_content('First poem')
      expect(page).to have_content('Second poem')
      expect(manifestation.reload.title).to eq('First poem')
    end
  end

  context 'when the editor lacks the batch_editing bit' do
    before do
      login_as(create(:user, :edit_catalog))
      visit manifestation_path(id: manifestation.id)
    end

    it 'does not offer the conversion' do
      expect(page).to have_css('.work-title')
      expect(page).to have_no_css('#convert-to-collection-btn')
      expect(page).to have_no_css('#convertToCollectionDlg', visible: :all)
    end
  end
end
