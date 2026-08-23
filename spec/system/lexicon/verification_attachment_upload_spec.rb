# frozen_string_literal: true

require 'rails_helper'

# Regression: the "upload file" button navigated to the layout-less attachments fragment, so no JS
# was loaded, the remote form fell back to a plain HTML POST, and the response was a 406 even though
# the file had already been attached.
RSpec.describe 'Uploading an attachment from the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:jpeg_path) { Rails.root.join('spec/fixtures/files/test_image.jpg') }

  it 'attaches the uploaded JPEG and shows it in the attachments section' do
    visit lexicon_verification_path(entry)

    within('#section-attachments') do
      click_link I18n.t('lexicon.verification.migrated.upload_file')
    end

    expect(page).to have_css('#generalDlg #new_attachment_form', visible: :visible, wait: 10)

    attach_file 'attachment', jpeg_path
    click_button I18n.t(:upload)

    # The page reloads once the upload succeeds, re-rendering the attachments section.
    expect(page).to have_css('#section-attachments', text: 'test_image.jpg', wait: 15)

    expect(entry.attachments.reload.map { |a| a.blob.filename.to_s }).to eq(['test_image.jpg'])
  end
end
