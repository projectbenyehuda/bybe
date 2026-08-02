# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LexCitation text links in the verification workbench', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:target_entry) { create(:lex_file, :publication, title: 'שדות ומזוודות').lex_entry }

  let!(:person) { create(:lex_person, birthdate: '1927', gender: :male) }

  let!(:entry) { create(:lex_entry, title: 'עמוס קינן', lex_item: person, status: :draft) }

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_citation_text_links.php')
    File.write(file_path, '<html><body><h1>עמוס קינן</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_citation_text_links.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let!(:citation) do
    create(:lex_citation,
           person: person,
           authors_count: 0,
           title: 'כל העסק מתפרק בכלל',
           from_publication: 'בספרו: שדות ומזוודות : תזות על הדרמה העברית',
           link: nil,
           text_links: [{ 'text' => 'שדות ומזוודות', 'entry_id' => target_entry.id }])
  end

  after { FileUtils.rm_f(Rails.root.join('tmp/test_citation_text_links.php')) }

  it 'renders the text link inside the citation publication line' do
    visit "/lex/verification/#{entry.id}"

    within "#citation-#{citation.id}" do
      expect(page).to have_link('שדות ומזוודות', href: "/lex/entries/#{target_entry.id}")
    end
  end

  it 'shows the existing text link in the citation edit modal' do
    visit "/lex/verification/#{entry.id}"

    within "#citation-#{citation.id}" do
      click_button I18n.t('lexicon.verification.migrated.edit')
    end

    expect(page).to have_css('#generalDlg.show', wait: 5)

    within '#generalDlg' do
      expect(page).to have_css('#text-links-list .badge', text: 'שדות ומזוודות', wait: 5)
    end
  end

  it 'adds a link to an arbitrary URL from the citation edit modal' do
    visit "/lex/verification/#{entry.id}"

    within "#citation-#{citation.id}" do
      click_button I18n.t('lexicon.verification.migrated.edit')
    end

    expect(page).to have_css('#generalDlg.show', wait: 5)

    within '#generalDlg' do
      expect(page).to have_css('#text-links-list .badge', text: 'שדות ומזוודות', wait: 5)
      fill_in 'text_link_text', with: 'תזות על הדרמה העברית'
      fill_in 'text_link_url', with: 'http://example.com/theses'
      click_button I18n.t(:add)

      expect(page).to have_css('#text-links-list .badge', text: 'תזות על הדרמה העברית', wait: 5)
    end

    expect(citation.reload.text_links).to include({ 'text' => 'תזות על הדרמה העברית',
                                                    'url' => 'http://example.com/theses' })
  end
end
