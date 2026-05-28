# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LexPersonWork title links in edit modal', type: :system, js: true do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:target_entry) { create(:lex_file, :person, title: 'אפרת דנון').lex_entry }

  let!(:person) do
    create(:lex_person, birthdate: '1970', gender: :female)
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_title_links_author.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_title_links_author.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let!(:work) do
    create(:lex_person_work,
           person: person,
           work_type: :edited,
           title: 'דג בבטן / אפרת דנון',
           title_links: [{ 'text' => 'אפרת דנון', 'entry_id' => target_entry.id }])
  end

  after { FileUtils.rm_f(Rails.root.join('tmp/test_title_links_author.php')) }

  it 'shows the existing title link in the edit modal opened from the verification page' do
    visit "/lex/verification/#{entry.id}"

    within "#work-#{work.id}" do
      click_button I18n.t('lexicon.verification.migrated.edit')
    end

    expect(page).to have_css('#generalDlg.show', wait: 5)

    within '#generalDlg' do
      # Wait for title-links AJAX to load
      expect(page).to have_css('#title-links-list', wait: 5)
      expect(page).to have_css('#title-links-list ul li', wait: 5)
      expect(page).to have_css('#title-links-list .badge', text: 'אפרת דנון', wait: 5)
    end
  end

  it 'shows the existing title link in the edit modal opened from the entry edit page' do
    visit "/lex/entries/#{entry.id}/edit"

    # Click the Works tab to trigger lazy-loading
    find('#works_tab').click
    expect(page).to have_css('#works .edit-person-work', wait: 10)

    # Click the edit link for our work
    find("#work_#{work.id} .edit-person-work").click

    expect(page).to have_css('#generalDlg.show', wait: 5)

    within '#generalDlg' do
      expect(page).to have_css('#title-links-list ul li', wait: 10)
      expect(page).to have_css('#title-links-list .badge', text: 'אפרת דנון', wait: 5)
    end
  end
end
