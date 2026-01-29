# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon entry proof submission', :js do
  let!(:lex_entry) { create(:lex_entry, :person, status: :published) }

  it 'allows users to submit error reports for lexicon entries' do
    visit lexicon_entry_path(lex_entry)

    # Verify the error-found button is visible
    expect(page).to have_css('#found_mistake', visible: true)

    # Execute JavaScript to select some text
    page.execute_script(<<~JS)
      const proofableDiv = document.querySelector('.proofable');
      const textNode = proofableDiv.querySelector('.headline-1-v02');
      if (textNode) {
        const range = document.createRange();
        range.selectNodeContents(textNode);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
      }
    JS

    # Click the error-found button
    find('#found_mistake').click

    # Wait for the modal to appear
    expect(page).to have_css('#proofDlg', visible: true, wait: 5)

    # Verify the selected text appears in the modal
    expect(page).to have_css('#proof_selected_text', visible: true)

    # Fill in the proof form
    fill_in 'what', with: 'This is a test error report'
    fill_in 'from', with: 'test@example.com'
    fill_in 'ziburit', with: 'ביאליק'

    # Submit the form
    click_button I18n.t('shared.proof.submit')

    # Wait for success modal (Bootstrap modal, not jQuery UI dialog)
    expect(page).to have_css('#proofSentDlg', visible: true, wait: 5)

    # Verify the proof was created
    proof = Proof.last
    expect(proof).to be_present
    expect(proof.item).to eq(lex_entry)
    expect(proof.item_type).to eq('LexEntry')
    expect(proof.what).to eq('This is a test error report')
    expect(proof.from).to eq('test@example.com')
    expect(proof.status).to eq('new')
  end

  it 'prevents submission without text selection' do
    visit lexicon_entry_path(lex_entry)

    # Click the button without selecting text - should trigger alert
    accept_alert do
      find('#found_mistake').click
    end

    # Should not open the modal
    expect(page).to have_no_css('#proofDlg', visible: true)
  end
end
