# frozen_string_literal: true

require 'rails_helper'

describe 'Verification Works Modal UX', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) do
    create(:lex_person, birthdate: '1900', deathdate: '1980', gender: :male)
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_author_works.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_author_works.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  # A work is required to get a per-work edit button in #section-works
  let!(:work) do
    create(:lex_person_work, person: person, title: 'Test Work', work_type: :original)
  end

  after { FileUtils.rm_f(lex_file.full_path) }

  describe 'per-work edit modal positioning and draggability' do
    before do
      visit "/lex/verification/#{entry.id}"
      within "#work-#{work.id}" do
        click_button I18n.t('lexicon.verification.migrated.edit')
      end
      # rubocop:disable RSpec/ExpectInHook
      expect(page).to have_css('#generalDlg.show', wait: 5)
      # rubocop:enable RSpec/ExpectInHook
    end

    it 'modal appears at the top of the viewport' do
      modal_top = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-dialog').getBoundingClientRect().top"
      )
      # Per-work edit modal has margin-top: 0 (full-height side panel)
      expect(modal_top).to be < 10
    end

    it 'modal content fills the viewport height as a full-height side panel' do
      modal_height = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-content').getBoundingClientRect().height"
      )
      viewport_height = page.evaluate_script('window.innerHeight')
      # Per-work edit modal uses height: 100vh
      expect(modal_height).to be >= (viewport_height * 0.9)
    end

    it 'modal header shows move cursor indicating draggability' do
      cursor = page.evaluate_script(
        "window.getComputedStyle(document.querySelector('#generalDlg .modal-header')).cursor"
      )
      expect(cursor).to eq('move')
    end

    it 'resize handles are present on all 8 directions' do
      handle_classes = page.evaluate_script(
        "Array.from(document.querySelectorAll('#generalDlg .modal-resize-handle')).map(h => h.className)"
      )
      %w(dlg-n dlg-ne dlg-e dlg-se dlg-s dlg-sw dlg-w dlg-nw).each do |dir|
        expect(handle_classes.any? { |c| c.include?(dir) }).to be true
      end
    end

    it 'dragging the SE corner handle increases modal size' do
      initial_w = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-dialog').getBoundingClientRect().width"
      )
      initial_h = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-content').getBoundingClientRect().height"
      )

      page.evaluate_script(<<~JS)
        (function() {
          var handle = document.querySelector('#generalDlg .modal-resize-handle.dlg-se');
          var rect = handle.getBoundingClientRect();
          var cx = rect.left + rect.width / 2;
          var cy = rect.top + rect.height / 2;
          handle.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true, clientX: cx, clientY: cy}));
          document.dispatchEvent(new MouseEvent('mousemove', {bubbles: true, cancelable: true, clientX: cx + 80, clientY: cy + 60}));
          document.dispatchEvent(new MouseEvent('mouseup',   {bubbles: true, cancelable: true}));
        })();
      JS

      new_w = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-dialog').getBoundingClientRect().width"
      )
      new_h = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-content').getBoundingClientRect().height"
      )
      expect(new_w).to be > initial_w
      expect(new_h).to be > initial_h
    end

    it 'dragging the modal header repositions the dialog' do
      initial_top = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-dialog').getBoundingClientRect().top"
      )

      # Simulate drag: mousedown on header, mousemove 100px down, mouseup
      page.evaluate_script(<<~JS)
        (function() {
          var header = document.querySelector('#generalDlg .modal-header');
          var rect = header.getBoundingClientRect();
          var cx = rect.left + rect.width / 2;
          var cy = rect.top + rect.height / 2;
          header.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true, clientX: cx, clientY: cy}));
          document.dispatchEvent(new MouseEvent('mousemove', {bubbles: true, cancelable: true, clientX: cx, clientY: cy + 100}));
          document.dispatchEvent(new MouseEvent('mouseup',   {bubbles: true, cancelable: true}));
        })();
      JS

      new_top = page.evaluate_script(
        "document.querySelector('#generalDlg .modal-dialog').getBoundingClientRect().top"
      )
      expect(new_top).to be > initial_top
    end
  end
end
