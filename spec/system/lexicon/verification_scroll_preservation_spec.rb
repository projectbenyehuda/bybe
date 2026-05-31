# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Verification Scroll Position Preservation', type: :system, js: true do
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

  # PHP file with enough paragraphs to exceed any typical viewport height
  let(:php_content) do
    lines = ['<html><body><h1>Test Person</h1>']
    80.times { |i| lines << "<p>Content paragraph #{i + 1}: legacy PHP test line for scroll testing.</p>" }
    lines << '</body></html>'
    lines.join("\n")
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_scroll_person.php')
    File.write(file_path, php_content)
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_scroll_person.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  # Extra citations to ensure the migrated pane has scrollable content
  let!(:citations) do
    6.times.map { |i| create(:lex_citation, person: person, title: "Citation #{i}", from_publication: "Pub #{i}") }
  end

  after { FileUtils.rm_f(lex_file.full_path) }

  # before must appear after let! blocks so that let! implicit before-hooks
  # (which create the file and DB records) execute before this hook visits the page.
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    entry.start_verification!('test@example.com')
    visit "/lex/verification/#{entry.id}"
  end

  # Async script that polls until the iframe has loaded real source content,
  # then resolves to its scrollY.  Times out at 5 seconds.
  def iframe_scroll_y_js
    <<~JS
      var done = arguments[0];
      var deadline = Date.now() + 5000;
      function check() {
        try {
          var iframe = document.querySelector('.source-iframe');
          if (!iframe) { done(-1); return; }
          var href = iframe.contentWindow.location.href;
          if (href && href !== 'about:blank') { done(iframe.contentWindow.scrollY); return; }
        } catch(e) {}
        if (Date.now() > deadline) { done(-1); } else { setTimeout(check, 100); }
      }
      check();
    JS
  end

  # Async script that polls until .migrated-content scrollTop >= threshold or timeout.
  def migrated_scroll_top_js(threshold: 50, timeout_ms: 2000)
    <<~JS
      var done = arguments[0];
      var deadline = Date.now() + #{timeout_ms};
      function check() {
        var el = document.querySelector('.migrated-content');
        var top = el ? el.scrollTop : 0;
        if (top >= #{threshold} || Date.now() > deadline) { done(top); }
        else { setTimeout(check, 50); }
      }
      check();
    JS
  end

  describe 'Source iframe scroll preservation' do
    it 'saves source_iframe_scroll_y to sessionStorage when saveScrollPositions is called' do
      expect(page).to have_css('.source-iframe', wait: 5)
      expect(page.evaluate_script("sessionStorage.getItem('source_iframe_scroll_y')")).to be_nil

      page.execute_script('saveScrollPositions()')

      expect(page.evaluate_script("sessionStorage.getItem('source_iframe_scroll_y')")).not_to be_nil
    end

    it 'does not save the legacy source_scroll_top key' do
      expect(page).to have_css('.source-iframe', wait: 5)
      page.execute_script('saveScrollPositions()')
      expect(page.evaluate_script("sessionStorage.getItem('source_scroll_top')")).to be_nil
    end

    it 'consumes source_iframe_scroll_y from sessionStorage on page load' do
      page.execute_script("sessionStorage.setItem('source_iframe_scroll_y', '80')")

      visit "/lex/verification/#{entry.id}"
      expect(page).to have_css('.source-iframe', wait: 10)

      expect(page.evaluate_script("sessionStorage.getItem('source_iframe_scroll_y')")).to be_nil
    end

    it 'restores the source iframe scroll position after a page reload' do
      page.execute_script("sessionStorage.setItem('source_iframe_scroll_y', '80')")

      visit "/lex/verification/#{entry.id}"
      expect(page).to have_css('.source-iframe', wait: 10)

      # Poll asynchronously until the iframe has loaded real content and scroll is applied
      scroll_y = page.evaluate_async_script(iframe_scroll_y_js)
      expect(scroll_y).to be >= 40
    end
  end

  describe 'Migrated pane scroll preservation' do
    it 'saves migrated_scroll_top to sessionStorage when saveScrollPositions is called' do
      expect(page).to have_css('.migrated-content', wait: 5)
      page.execute_script('saveScrollPositions()')
      expect(page.evaluate_script("sessionStorage.getItem('migrated_scroll_top')")).not_to be_nil
    end

    it 'restores migrated pane scroll position after a page reload' do
      expect(page).to have_css('.migrated-content', wait: 5)

      # Scroll the pane and measure the actual scrollTop (clamped to content height)
      page.execute_script("document.querySelector('.migrated-content').scrollTop = 100")
      actual_before = page.evaluate_script("document.querySelector('.migrated-content').scrollTop")
      skip 'Migrated content is not tall enough to scroll' if actual_before < 50

      # Simulate what saveScrollPositions() does, then navigate (like location.reload())
      page.execute_script("sessionStorage.setItem('migrated_scroll_top', '#{actual_before}')")
      visit "/lex/verification/#{entry.id}"
      expect(page).to have_css('.verification-container', wait: 5)

      # sessionStorage key should have been consumed by initVerification
      expect(page.evaluate_script("sessionStorage.getItem('migrated_scroll_top')")).to be_nil

      # Poll asynchronously until the rAF-based retry has applied the scroll
      scroll_top = page.evaluate_async_script(migrated_scroll_top_js)
      expect(scroll_top).to be >= 50
    end

    it 'clears the legacy source_scroll_top key from sessionStorage on page load' do
      page.execute_script("sessionStorage.setItem('source_scroll_top', '123')")
      visit "/lex/verification/#{entry.id}"
      expect(page).to have_css('.verification-container', wait: 5)
      expect(page.evaluate_script("sessionStorage.getItem('source_scroll_top')")).to be_nil
    end
  end
end
