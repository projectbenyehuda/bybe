require 'rails_helper'

RSpec.describe 'Ingestible duplicate volume validation', type: :system do
  let!(:authority) { create(:authority, name: 'אהרן אמיר') }
  let!(:publication) do
    create(:publication, id: 1771, title: 'ביזאנטיון / מאת פיליפ שרארד ועורכי ספריית טיים-לייף ; (מאנגלית לעברית - אהרן אמיר).', authority: authority)
  end

  before do

    # Create an existing ingestible proposing to create a volume from this publication
    create(:ingestible,
           title: 'בד1',
           status: :draft,
           prospective_volume_id: "P#{publication.id}",
           prospective_volume_title: publication.title,
           collection_authorities: "[{\"seqno\":1,\"authority_id\":#{authority.id},\"authority_name\":\"אהרן אמיר\",\"role\":\"author\"}]")

    # Login as catalog editor
    login_as_catalog_editor
  end

  it 'gracefully shows validation error instead of error 500' do
    visit new_ingestible_path

    # Fill in the form
    fill_in 'ingestible_title', with: 'בד2'
    fill_in 'ingestible_prospective_volume_title', with: publication.title
    find('#prospective_volume_id', visible: false).set("P#{publication.id}")

    # Submit the form
    expect {
      click_button I18n.t(:save)
    }.not_to raise_error

    # Should not get error 500, should show validation error
    expect(page).not_to have_content('Internal Server Error')
    expect(page).not_to have_content('500')

    # Should show the validation error message
    expect(page).to have_content(I18n.t('ingestible.errors.another_ingestible_proposing_volume'))

    # Should still be on the form page
    expect(page).to have_field('ingestible_title')
  end

  it 'handles malformed JSON in collection_authorities gracefully' do
    # Create an ingestible with malformed JSON
    bad_ingestible = create(:ingestible,
                            title: 'Bad JSON',
                            status: :draft,
                            prospective_volume_id: "P#{publication.id}",
                            collection_authorities: '{invalid json}')

    visit edit_ingestible_path(bad_ingestible)

    # Should not get error 500 when loading the page
    expect(page).not_to have_content('Internal Server Error')
    expect(page).not_to have_content('500')

    # Should show error message for malformed JSON in the view
    expect(page).to have_content(I18n.t('ingestible.errors.invalid_json_in_collection_authorities'))
  end
end
