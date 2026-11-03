# frozen_string_literal: true

require 'rails_helper'

describe 'Ingestible per-text secondary and Sefaria linker flags', :js, type: :system do
  let!(:ingestible) do
    create(:ingestible,
           markdown: "&&& Test Work 1\n\nSome content here.",
           works_buffer: [{ title: 'Test Work 1', content: 'Some content here.' }].to_json,
           works_buffer_updated_at: 1.minute.from_now,
           toc_buffer: 'yes || Test Work 1 ||  || poetry || he || ')
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_catalog_editor
  end

  it 'persists the checkboxes in the texts tab' do
    visit edit_ingestible_path(ingestible, text_index: 0)
    within('#ingestible_edit_texts') do
      expect(page).to have_unchecked_field('ingestible_text_secondary', wait: 5)
      expect(page).to have_unchecked_field('ingestible_text_sefaria_linker')
      check 'ingestible_text_secondary'
      check 'ingestible_text_sefaria_linker'
      click_button I18n.t(:save)
    end

    expect(page).to have_checked_field('ingestible_text_secondary', wait: 5)
    expect(page).to have_checked_field('ingestible_text_sefaria_linker')
    expect(ingestible.reload.texts.first).to have_attributes(secondary: true, sefaria_linker: true)
  end
end
