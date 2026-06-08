# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LexPersonWork comment links in edit modal', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:target_entry) { create(:lex_file, :person, title: 'יגאל שוורץ').lex_entry }

  let!(:person) do
    create(:lex_person, birthdate: '1970', gender: :female)
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_comment_links_author.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_comment_links_author.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let!(:work) do
    create(:lex_person_work,
           person: person,
           work_type: :original,
           title: 'מעיל קטון',
           comment: 'כולל אחרית דבר מאת יגאל שוורץ',
           comment_links: [{ 'text' => 'יגאל שוורץ', 'entry_id' => target_entry.id }])
  end

  after { FileUtils.rm_f(Rails.root.join('tmp/test_comment_links_author.php')) }

  it 'renders the comment link on the verification page' do
    visit "/lex/verification/#{entry.id}"

    within "#work-#{work.id}" do
      expect(page).to have_link('יגאל שוורץ', href: "/lex/entries/#{target_entry.id}")
    end
  end

  it 'shows the existing comment link in the edit modal' do
    visit "/lex/verification/#{entry.id}"

    within "#work-#{work.id}" do
      click_button I18n.t('lexicon.verification.migrated.edit')
    end

    expect(page).to have_css('#generalDlg.show', wait: 5)

    within '#generalDlg' do
      # Wait for comment-links AJAX to load
      expect(page).to have_css('#comment-links-list ul li', wait: 5)
      expect(page).to have_css('#comment-links-list .badge', text: 'יגאל שוורץ', wait: 5)
    end
  end
end
