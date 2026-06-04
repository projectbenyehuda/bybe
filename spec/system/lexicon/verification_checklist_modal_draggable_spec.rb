# frozen_string_literal: true

require 'rails_helper'

describe 'Verification Checklist Modal draggability', :js do
  let!(:person) do
    create(:lex_person, birthdate: '1900', deathdate: '1980', gender: :male)
  end

  let!(:entry) do
    create(:lex_entry, title: 'Test Author', lex_item: person, status: :draft)
  end

  let!(:lex_file) do
    file_path = Rails.root.join('tmp/test_author_checklist.php')
    File.write(file_path, '<html><body><h1>Test Author</h1></body></html>')
    create(:lex_file,
           lex_entry: entry,
           fname: 'test_author_checklist.php',
           full_path: file_path.to_s,
           status: :ingested,
           entrytype: :person)
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
    visit "/lex/verification/#{entry.id}"
    click_button I18n.t('lexicon.verification.checklist.title')
    # rubocop:disable RSpec/ExpectInHook
    expect(page).to have_css('#checklistModal.show', wait: 5)
    # rubocop:enable RSpec/ExpectInHook
  end

  after { FileUtils.rm_f(lex_file.full_path) }

  it 'modal header shows move cursor indicating draggability' do
    cursor = page.evaluate_script(
      "window.getComputedStyle(document.querySelector('#checklistModal .modal-header')).cursor"
    )
    expect(cursor).to eq('move')
  end

  it 'resize handles are present on all 8 directions' do
    handle_classes = page.evaluate_script(
      "Array.from(document.querySelectorAll('#checklistModal .modal-resize-handle')).map(h => h.className)"
    )
    %w(dlg-n dlg-ne dlg-e dlg-se dlg-s dlg-sw dlg-w dlg-nw).each do |dir|
      expect(handle_classes.any? { |c| c.include?(dir) }).to be true
    end
  end

  it 'dragging the modal header repositions the dialog' do
    initial_top = page.evaluate_script(
      "document.querySelector('#checklistModal .modal-dialog').getBoundingClientRect().top"
    )

    # Simulate drag: mousedown on header, mousemove 100px down, mouseup
    page.evaluate_script(<<~JS)
      (function() {
        var header = document.querySelector('#checklistModal .modal-header');
        var rect = header.getBoundingClientRect();
        var cx = rect.left + rect.width / 2;
        var cy = rect.top + rect.height / 2;
        header.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, cancelable: true, clientX: cx, clientY: cy}));
        document.dispatchEvent(new MouseEvent('mousemove', {bubbles: true, cancelable: true, clientX: cx, clientY: cy + 100}));
        document.dispatchEvent(new MouseEvent('mouseup',   {bubbles: true, cancelable: true}));
      })();
    JS

    new_top = page.evaluate_script(
      "document.querySelector('#checklistModal .modal-dialog').getBoundingClientRect().top"
    )
    expect(new_top).to be > initial_top
  end
end
