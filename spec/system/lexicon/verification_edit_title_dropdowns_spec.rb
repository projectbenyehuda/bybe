# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification – edit title section dropdowns', :js do
  let!(:person) { create(:lex_person, gender: :male, copyrighted: false) }
  let!(:entry) { create(:lex_entry, title: 'Test Person', lex_item: person, status: :draft) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    visit "/lex/verification/#{entry.id}"

    within('#section-title .section-actions') do
      click_button I18n.t('lexicon.verification.migrated.edit')
    end
    find('#generalDlg', visible: true, wait: 5)
  end

  it 'gender dropdown has visible, non-blank options' do
    within('#generalDlgBody') do
      gender_select = find('select[name="lex_person[gender]"]')
      option_texts = gender_select.all('option').map(&:text).map(&:strip).compact_blank
      expect(option_texts).to include('זכר', 'נקבה', 'אחר', 'לא ידוע')
    end
  end

  it 'can select a gender value and save it' do
    within('#generalDlgBody') do
      select 'נקבה', from: 'lex_person[gender]'
      find('[type="submit"]').click
    end

    expect(page).to have_css('#section-title', wait: 5)
    person.reload
    expect(person.gender).to eq('female')
  end
end
