# frozen_string_literal: true

require 'rails_helper'

# Issue #1857: an entry migrated with a single image gets it as the profile image by default, and
# the reviewer must be able to clear that designation when the image is not a portrait.
RSpec.describe 'Profile image on the verification page', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    entry.attachments.attach(io: Rails.root.join('spec/fixtures/files/test_image.jpg').open,
                             filename: 'test_image.jpg', content_type: 'image/jpeg')
    entry.update!(profile_image_id: entry.attachments.first.id)
  end

  let(:entry) { create(:lex_entry, :person, status: :draft) }
  let(:badge_text) { I18n.t('lexicon.verification.migrated.profile_image_badge') }

  it 'shows the image as the profile image, and lets the reviewer clear it' do
    visit lexicon_verification_path(entry)

    within('#section-attachments') do
      expect(page).to have_css('.attachment-item.profile-image-selected .profile-image-badge', text: badge_text)

      click_button "✓ #{badge_text}"

      expect(page).to have_button(I18n.t('lexicon.verification.migrated.use_as_profile'), wait: 5)
      expect(page).to have_no_css('.profile-image-selected')
      expect(page).to have_no_css('.profile-image-badge')
    end

    expect(entry.reload.profile_image_id).to be_nil
  end
end
