# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Verification migrated pane section shortcuts', :js, type: :system do
  let(:php_content) do
    lines = ['<html><body><h1>Test Person</h1>']
    20.times { |i| lines << "<p>Content paragraph #{i + 1}.</p>" }
    lines << '</body></html>'
    lines.join("\n")
  end

  # Poll until .migrated-content scrollTop stops changing (smooth scrolling has settled).
  # scrollTop can be fractional and jitter by well under a pixel, so "unchanged" is an
  # epsilon comparison rather than strict equality.
  def settled_migrated_scroll_top_js
    <<~JS
      var done = arguments[0];
      var el = document.querySelector('.migrated-content');
      var last = -1;
      var stable = 0;
      var deadline = Date.now() + 5000;
      function check() {
        var top = el ? el.scrollTop : 0;
        if (Math.abs(top - last) < 0.5) { stable++; } else { stable = 0; }
        last = top;
        if (stable >= 3 || Date.now() > deadline) { done(top); }
        else { setTimeout(check, 100); }
      }
      check();
    JS
  end

  def section_offset_in_pane(section_id)
    page.evaluate_script(<<~JS)
      (function() {
        var el = document.getElementById('#{section_id}');
        var pane = document.querySelector('.migrated-content');
        return Math.round(el.getBoundingClientRect().top - pane.getBoundingClientRect().top);
      })()
    JS
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  context 'with a person entry' do
    let!(:person) do
      create(:lex_person,
             birthdate: '1138',
             deathdate: '1204',
             bio: (['<p>A long biography paragraph.</p>'] * 40).join("\n"),
             gender: :male)
    end

    let!(:entry) { create(:lex_entry, title: 'Test Person', lex_item: person, status: :draft) }

    let!(:lex_file) do
      file_path = Rails.root.join('tmp/test_shortcuts_person.php')
      File.write(file_path, php_content)
      create(:lex_file,
             lex_entry: entry,
             fname: 'test_shortcuts_person.php',
             full_path: file_path.to_s,
             status: :ingested,
             entrytype: :person)
    end

    let!(:citations) do
      6.times.map { |i| create(:lex_citation, person: person, title: "Citation #{i}", from_publication: "Pub #{i}") }
    end

    after { FileUtils.rm_f(lex_file.full_path) }

    before do
      entry.start_verification!('test@example.com')
      visit "/lex/verification/#{entry.id}"
      find('.migrated-content', wait: 5)
    end

    it 'shows a shortcut in the header for each of the four sections' do
      within '.migrated-header .migrated-shortcuts' do
        %w(section-bio section-works section-citations section-links).each do |section_id|
          expect(page).to have_css(%(.migrated-shortcut[data-section-target="#{section_id}"]), visible: :visible)
        end
      end
    end

    it 'labels the shortcuts with the section names' do
      within '.migrated-header .migrated-shortcuts' do
        expect(page).to have_link(I18n.t('lexicon.verification.sections.biography'))
        expect(page).to have_link(I18n.t('lexicon.verification.sections.works_section'))
        expect(page).to have_link(I18n.t('lexicon.verification.sections.citations_section'))
        expect(page).to have_link(I18n.t('lexicon.verification.sections.links_section'))
      end
    end

    it 'scrolls the migrated pane to the citations section when its shortcut is clicked' do
      expect(page.evaluate_script("document.querySelector('.migrated-content').scrollTop")).to eq(0)

      find('.migrated-shortcut[data-section-target="section-citations"]').click

      expect(page.evaluate_async_script(settled_migrated_scroll_top_js)).to be > 0
      # The section should end up at the top of the pane (8px margin allowed for by the JS)
      expect(section_offset_in_pane('section-citations')).to be_within(12).of(8)
    end

    it 'scrolls back up to the biography section' do
      find('.migrated-shortcut[data-section-target="section-links"]').click
      expect(page.evaluate_async_script(settled_migrated_scroll_top_js)).to be > 0

      find('.migrated-shortcut[data-section-target="section-bio"]').click
      page.evaluate_async_script(settled_migrated_scroll_top_js)

      expect(section_offset_in_pane('section-bio')).to be_within(12).of(8)
    end

    it 'does not change the page URL' do
      url_before = page.current_url
      find('.migrated-shortcut[data-section-target="section-works"]').click
      page.evaluate_async_script(settled_migrated_scroll_top_js)

      expect(page.current_url).to eq(url_before)
    end
  end

  context 'with a publication entry' do
    let!(:entry) do
      create(:lex_entry, title: 'Test Publication', status: :draft,
                         lex_item: build(:lex_publication, az_navbar: true))
    end

    let!(:lex_file) do
      file_path = Rails.root.join('tmp/test_shortcuts_publication.php')
      File.write(file_path, php_content)
      create(:lex_file,
             lex_entry: entry,
             fname: 'test_shortcuts_publication.php',
             full_path: file_path.to_s,
             status: :ingested,
             entrytype: :text)
    end

    after { FileUtils.rm_f(lex_file.full_path) }

    before do
      entry.start_verification!('test@example.com')
      visit "/lex/verification/#{entry.id}"
      find('.migrated-content', wait: 5)
    end

    it 'hides shortcuts whose section is not rendered for publications' do
      %w(section-bio section-works section-citations).each do |section_id|
        expect(page).to have_css(%(.migrated-shortcut[data-section-target="#{section_id}"]), visible: :hidden)
      end
    end

    it 'keeps the links shortcut, which publications do have' do
      expect(page).to have_css('.migrated-shortcut[data-section-target="section-links"]', visible: :visible)
    end

    it 'keeps the shortcuts nav itself visible' do
      expect(page).to have_css('.migrated-shortcuts', visible: :visible)
    end
  end
end
