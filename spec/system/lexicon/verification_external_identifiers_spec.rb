# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification Workbench – External Identifiers', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    visit "/lex/verification/#{entry.id}"
  end

  let!(:person) { create(:lex_person, birthdate: '1880', deathdate: '1945') }
  let!(:entry) do
    create(:lex_entry,
           title: 'Test Author',
           lex_item: person,
           status: :draft,
           external_identifiers: { 'viaf' => '12345678', 'lc' => 'n87654321' })
  end

  describe 'display section' do
    it 'shows the external identifiers section in the migrated entry panel' do
      within('.verification-migrated') do
        expect(page).to have_css('#section-external-identifiers')
        expect(page).to have_content(I18n.t('lexicon.verification.sections.external_identifiers_section'))
      end
    end

    it 'displays the migrated identifier keys and values' do
      within('#section-external-identifiers') do
        expect(page).to have_content('VIAF')
        expect(page).to have_content('12345678')
        expect(page).to have_content('LC')
        expect(page).to have_content('n87654321')
      end
    end

    it 'shows an edit button for the section' do
      within('#section-external-identifiers .section-actions') do
        expect(page).to have_button(I18n.t('lexicon.verification.migrated.edit'))
      end
    end

    it 'shows a mark-as-verified button for the section' do
      within('#section-external-identifiers .section-actions') do
        expect(page).to have_button(I18n.t('lexicon.verification.migrated.mark_verified'))
      end
    end

    context 'when entry has no external identifiers' do
      let!(:entry) do
        create(:lex_entry,
               title: 'Author Without IDs',
               lex_item: person,
               status: :draft,
               external_identifiers: nil)
      end

      it 'shows the no-identifiers placeholder' do
        within('#section-external-identifiers') do
          expect(page).to have_content(I18n.t('lexicon.verification.sections.no_external_identifiers'))
        end
      end
    end
  end

  describe 'checklist' do
    it 'shows external_identifiers in the verification checklist' do
      within('.verification-checklist') do
        expect(page).to have_content(I18n.t('lexicon.verification.checklist.person.external_identifiers'))
      end
    end

    it 'can mark external_identifiers as verified via the quick verify button' do
      within('#section-external-identifiers .section-actions') do
        find('button[data-action="click->verification#quickVerify"]').click
      end

      entry.reload
      expect(entry.verification_progress.dig('checklist', 'external_identifiers', 'verified')).to be true
    end
  end

  describe 'edit modal' do
    before do
      within('#section-external-identifiers .section-actions') do
        click_button I18n.t('lexicon.verification.migrated.edit')
      end
      find('#generalDlg', visible: true, wait: 5)
    end

    it 'opens an edit modal with identifier fields' do
      within('#generalDlgBody') do
        expect(page).to have_field('external_identifiers[viaf]', with: '12345678')
        expect(page).to have_field('external_identifiers[lc]', with: 'n87654321')
      end
    end

    it 'mark_verified checkbox is unchecked when section is not yet verified' do
      within('#generalDlgBody') do
        expect(page).to have_unchecked_field('mark_verified')
      end
    end

    it 'updates identifiers when the form is saved' do
      within('#generalDlgBody') do
        fill_in 'external_identifiers[viaf]', with: '99999999'
        find('[type="submit"]').click
      end

      expect(page).to have_css('#section-external-identifiers', wait: 5)
      entry.reload
      expect(entry.external_identifiers['viaf']).to eq('99999999')
    end

    it 'removes an identifier when its field is cleared' do
      within('#generalDlgBody') do
        fill_in 'external_identifiers[lc]', with: ''
        find('[type="submit"]').click
      end

      expect(page).to have_css('#section-external-identifiers', wait: 5)
      entry.reload
      expect(entry.external_identifiers).not_to have_key('lc')
    end

    it 'marks the section as verified when the checkbox is checked' do
      within('#generalDlgBody') do
        check 'mark_verified'
        find('[type="submit"]').click
      end

      # Wait for the section to reflect the verified state before querying the DB
      expect(page).to have_css('#section-external-identifiers.verified', wait: 10)
      entry.reload
      expect(entry.verification_progress.dig('checklist', 'external_identifiers', 'verified')).to be true
    end
  end

  describe 'edit modal when section is already verified' do
    before do
      entry.start_verification!('test@example.com')
      entry.update_checklist_item('external_identifiers', true, '')

      visit "/lex/verification/#{entry.id}"
      within('#section-external-identifiers .section-actions') do
        click_button I18n.t('lexicon.verification.migrated.edit')
      end
      find('#generalDlg', visible: true, wait: 5)
    end

    it 'pre-checks the mark_verified checkbox' do
      within('#generalDlgBody') do
        expect(page).to have_checked_field('mark_verified')
      end
    end
  end
end
