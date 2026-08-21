# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Verification release lock button', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) { create(:lex_person, birthdate: '1138', deathdate: '1204', gender: :male) }
  let!(:entry) { create(:lex_entry, title: 'Test Person', lex_item: person, status: :draft) }

  it 'releases the lock and returns to the verification queue' do
    visit "/lex/verification/#{entry.id}"

    # Visiting the workbench acquires the lock for the current editor.
    expect(entry.reload).to be_locked

    accept_confirm { click_button I18n.t('lexicon.verification.show.release_lock') }

    expect(page).to have_content(I18n.t('lexicon.verification.unlock.success'))
    expect(page).to have_current_path(lexicon_verification_queue_path)
    expect(entry.reload).not_to be_locked
  end

  it 'keeps the lock when the confirmation is dismissed' do
    visit "/lex/verification/#{entry.id}"
    expect(entry.reload).to be_locked

    dismiss_confirm { click_button I18n.t('lexicon.verification.show.release_lock') }

    expect(page).to have_current_path("/lex/verification/#{entry.id}")
    expect(entry.reload).to be_locked
  end
end
