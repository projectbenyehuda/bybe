# frozen_string_literal: true

require 'rails_helper'

describe 'Reporting a publication missing from the lexicon entry', :js do
  let!(:authority) { create(:authority, name: 'Test Author') }
  let!(:person) { create(:lex_person, authority: authority, birthdate: '1900', deathdate: '1980', gender: :male) }
  let!(:entry) { create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft) }
  let!(:publication) { create(:publication, authority: authority, title: 'Unmatched Publication') }

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_author_missing_publication.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_author_missing_publication.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  let(:row_selector) { "#generalDlgBody #unmatched-publication-#{publication.id}" }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    allow(Lexicon::MondayReport).to receive(:call).and_return({ success: true })
    login_as_lexicon_editor
    visit "/lex/verification/#{entry.id}"
  end

  after { FileUtils.rm_f(lex_file.full_path) }

  # The list lives at the bottom of the works auto-match popup
  def open_works_popup
    click_button I18n.t('lexicon.verification.sections.auto_match_works_btn')
    expect(page).to have_css('#generalDlgBody',
                             text: I18n.t('lexicon.verification.sections.unmatched_publications_heading'))
  end

  it 'lists the unmatched publication and replaces its report button with a label once reported' do
    open_works_popup
    expect(page).to have_css("#{row_selector} .monday-missing-work-btn", visible: :visible)

    find("#{row_selector} .monday-missing-work-btn").click

    expect(page).to have_no_css("#{row_selector} .monday-missing-work-btn", wait: 5)
    # The publication itself stays listed, with a label in place of the button
    expect(page).to have_css("#{row_selector} .reported-missing-label",
                             text: I18n.t('lexicon.verification.monday.missing_work_reported'))
    expect(Lexicon::MondayReport).to have_received(:call).with(
      hash_including(report_type: :missing_work, publication: publication)
    )
  end

  it 'does not offer the button again after a reload' do
    open_works_popup
    find("#{row_selector} .monday-missing-work-btn").click
    expect(page).to have_css("#{row_selector} .reported-missing-label", wait: 5)

    visit "/lex/verification/#{entry.id}"
    open_works_popup

    expect(page).to have_css("#{row_selector} .reported-missing-label")
    expect(page).to have_no_css('.monday-missing-work-btn')
  end
end
