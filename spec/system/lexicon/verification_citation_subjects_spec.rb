# frozen_string_literal: true

require 'rails_helper'

describe 'Verification citation subject headings section', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) { create(:lex_person, birthdate: '1900', deathdate: '1980', gender: :male) }
  let!(:entry) { create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft) }

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_author_citation_subjects.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_author_citation_subjects.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let!(:work) { create(:lex_person_work, person: person, title: 'אור פרא : שירים', work_type: :original) }
  let!(:matched_citation) { create(:lex_citation, person: person, subject: 'על "אור פרא"') }
  let!(:generic_citation) { create(:lex_citation, person: person, subject: 'מאמרים') }
  let!(:unmatched_citation) { create(:lex_citation, person: person, subject: 'רשימות מבית המרזח') }

  after { FileUtils.rm_f(lex_file.full_path) }

  def open_auto_match_modal
    find('#citation-subjects-auto-match-btn').click
    expect(page).to have_css('#generalDlg.show .auto-match-citation-subjects-modal', wait: 5)
  end

  it 'lists the unresolved headings on the section card' do
    visit "/lex/verification/#{entry.id}"

    within '#section-citation-subjects' do
      expect(page).to have_content('על "אור פרא"')
      expect(page).to have_content('מאמרים')
      expect(page).to have_content('רשימות מבית המרזח')
    end
  end

  it 'badges each citations group by whether its heading is linked to a work yet' do
    create(:lex_citation, person: person, person_work: work, subject: nil)
    visit "/lex/verification/#{entry.id}"

    within '#section-citations' do
      linked = find('.subject-header', text: work.title)
      expect(linked).to have_content(I18n.t('lexicon.verification.sections.citation_group_linked'))

      unlinked = find('.subject-header', text: 'רשימות מבית המרזח')
      expect(unlinked).to have_content(I18n.t('lexicon.verification.sections.citation_group_unlinked'))
    end
  end

  it 'refuses to mark the section verified before the modal has been opened' do
    visit "/lex/verification/#{entry.id}"

    within '#section-citation-subjects .section-actions' do
      expect(page).to have_button(I18n.t('lexicon.verification.migrated.mark_verified'), disabled: true)
    end
  end

  it 'links every citation under a proposed heading to the matched work' do
    visit "/lex/verification/#{entry.id}"
    open_auto_match_modal

    within '#generalDlg' do
      row = find('.citation-subject-match', text: 'על "אור פרא"')
      expect(row).to have_content('אור פרא : שירים')
      row.click_button I18n.t('lexicon.verification.edit.confirm_match')
      expect(row).to have_css('.text-success', wait: 5)
    end

    expect(matched_citation.reload.person_work).to eq work
    expect(matched_citation.subject).to be_nil
  end

  it 'clears a generic heading without linking it to a work' do
    visit "/lex/verification/#{entry.id}"
    open_auto_match_modal

    within '#generalDlg' do
      row = find('.citation-subject-match', text: 'מאמרים')
      expect(row).to have_content(I18n.t('lexicon.verification.sections.citation_subject_general'))
      row.click_button I18n.t('lexicon.verification.edit.confirm_match')
      expect(row).to have_css('.text-success', wait: 5)
    end

    expect(generic_citation.reload.subject).to be_nil
    expect(generic_citation.person_work).to be_nil
  end

  it 'lets the editor assign a work to a heading nothing matched' do
    visit "/lex/verification/#{entry.id}"
    open_auto_match_modal

    within '#generalDlg' do
      row = find('.citation-subject-unmatched', text: 'רשימות מבית המרזח')
      row.find('.citation-subject-work-select').select work.title
      row.click_button I18n.t('lexicon.verification.sections.citation_subject_assign')
      expect(row).to have_css('.text-success', wait: 5)
    end

    expect(unmatched_citation.reload.person_work).to eq work
    expect(unmatched_citation.subject).to be_nil
  end

  it 'enables marking the section verified once the modal has been opened' do
    visit "/lex/verification/#{entry.id}"
    open_auto_match_modal
    within('#generalDlg') { click_button I18n.t('lexicon.verification.sections.close') }

    expect(page).to have_css('#section-citation-subjects', wait: 5)
    within '#section-citation-subjects .section-actions' do
      expect(page).to have_button(I18n.t('lexicon.verification.migrated.mark_verified'), disabled: false, wait: 5)
    end
  end
end
