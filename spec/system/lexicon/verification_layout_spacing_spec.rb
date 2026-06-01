# frozen_string_literal: true

require 'rails_helper'

# Regression coverage for the verification workbench vertical layout: the two
# panes must fill the remaining viewport (no blank gap below them) and only the
# panes scroll internally — the page itself must not produce a full-page scroll.
RSpec.describe 'Verification workbench layout spacing', type: :system, js: true do
  let!(:person) do
    create(:lex_person,
           birthdate: '1138',
           deathdate: '1204',
           bio: '<p>A biography paragraph.</p>',
           gender: :male)
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Person', lex_item: person, status: :draft)
  end

  let(:php_content) do
    lines = ['<html><body><h1>Test Person</h1>']
    80.times { |i| lines << "<p>Content paragraph #{i + 1}: legacy PHP test line.</p>" }
    lines << '</body></html>'
    lines.join("\n")
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_layout_person.php')
    File.write(file_path, php_content)
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_layout_person.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  # Enough citations to make the migrated pane taller than the viewport.
  let!(:citations) do
    20.times.map { |i| create(:lex_citation, person: person, title: "Citation #{i}", from_publication: "Pub #{i}") }
  end

  after { FileUtils.rm_f(lex_file.full_path) }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    entry.start_verification!('test@example.com')
    visit "/lex/verification/#{entry.id}"
  end

  it 'fills the viewport so the panes reach the bottom with no large blank gap' do
    expect(page).to have_css('.verification-container', wait: 5)

    gap = page.evaluate_script(<<~JS)
      (function() {
        var c = document.querySelector('.verification-container');
        return window.innerHeight - c.getBoundingClientRect().bottom;
      })()
    JS

    # The panes should end at (or very near) the viewport bottom; the previous
    # hardcoded `calc(100vh - 300px)` left ~80px of dead space here.
    expect(gap).to be >= 0
    expect(gap).to be < 30
  end

  it 'does not produce a full-page vertical scroll' do
    expect(page).to have_css('.verification-container', wait: 5)

    overflowing = page.evaluate_script(
      'document.documentElement.scrollHeight > window.innerHeight + 2'
    )
    expect(overflowing).to be false
  end

  it 'scrolls the migrated pane internally rather than the page' do
    expect(page).to have_css('.migrated-content', wait: 5)

    scrollable = page.evaluate_script(<<~JS)
      (function() {
        var el = document.querySelector('.migrated-content');
        return el.scrollHeight > el.clientHeight;
      })()
    JS
    expect(scrollable).to be true
  end
end
