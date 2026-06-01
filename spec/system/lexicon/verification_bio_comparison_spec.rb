# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon Verification bio comparison', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  # Legacy bio has 7 words; migrated bio has 2. The 5-word gap exceeds the
  # two-word tolerance, so the discrepancy warning should appear.
  let!(:person) do
    create(:lex_person, birthdate: '1900', deathdate: '1970', gender: :male,
                        bio: '<p>אחת שתיים</p>')
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Person', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_bio_comparison.php')
    File.write(file_path, <<~HTML)
      <html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head><body>
        <table width="100%"><tr><td><p align="center"><font size="4">(1900-1970)</font></p></td></tr></table>
        <p>אחת שתיים שלוש ארבע חמש שש שבע</p>
        <p><font><a name="Books"></a>ספרים</font></p>
      </body></html>
    HTML

    create(:lex_file, lex_entry: entry, fname: 'test_bio_comparison.php',
                      full_path: file_path.to_s, status: :ingested, entrytype: :person)
  end

  after do
    FileUtils.rm_f(lex_file.full_path)
  end

  it 'warns about the word-count discrepancy and opens the comparison modal' do
    visit "/lex/verification/#{entry.id}"

    within '#section-bio' do
      expect(page).to have_button(I18n.t('lexicon.verification.sections.compare_button'))
      click_button I18n.t('lexicon.verification.sections.compare_button')
    end

    expect(page).to have_content(I18n.t('lexicon.verification.bio_comparison.title'), wait: 5)
    expect(page).to have_content(I18n.t('lexicon.verification.bio_comparison.legacy_header'))
    expect(page).to have_content(I18n.t('lexicon.verification.bio_comparison.migrated_header'))
    # A word present only in the legacy source is highlighted as an insertion.
    expect(page).to have_css('.bio-diff-body .diff ins', text: 'שלוש')
  end

  it 'scrolls both panes to the first highlight when the modal opens' do
    # A long identical prefix pushes the first difference below the fold, so the
    # panes must scroll for the highlight to be visible.
    prefix = (['מילה'] * 250).join(' ')
    # migrated ends with 1 distinct word, legacy with 5 -> word-count diff of 4
    # (exceeds the tolerance) and a highlight on each side near the bottom.
    File.write(lex_file.full_path, <<~HTML)
      <html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head><body>
        <table width="100%"><tr><td><p align="center"><font size="4">(1900-1970)</font></p></td></tr></table>
        <p>#{prefix} ביתא גמא דלתא הא וו</p>
        <p><font><a name="Books"></a>ספרים</font></p>
      </body></html>
    HTML
    person.update!(bio: "<p>#{prefix} אלפא</p>")
    Rails.cache.delete("lex_file_content_#{lex_file.id}")

    visit "/lex/verification/#{entry.id}"
    within('#section-bio') { click_button I18n.t('lexicon.verification.sections.compare_button') }

    expect(page).to have_css('.bio-diff-body .diff ins', text: 'ביתא', wait: 5)
    # The legacy pane (index 0) and migrated pane (index 1) both scrolled down.
    expect(page).to have_css('.bio-diff-body .diff del', text: 'אלפא')
    legacy_scroll = page.evaluate_script("document.querySelectorAll('.bio-diff-pane')[0].scrollTop")
    migrated_scroll = page.evaluate_script("document.querySelectorAll('.bio-diff-pane')[1].scrollTop")
    expect(legacy_scroll).to be > 0
    expect(migrated_scroll).to be > 0
  end

  it 'does not warn when word counts are within tolerance' do
    person.update!(bio: '<p>אחת שתיים שלוש ארבע חמש</p>') # 5 words vs 7 -> diff 2

    visit "/lex/verification/#{entry.id}"

    within '#section-bio' do
      expect(page).to have_no_button(I18n.t('lexicon.verification.sections.compare_button'))
    end
  end
end
