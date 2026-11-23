# frozen_string_literal: true

require 'rails_helper'

describe 'Ingestible mediating language', :js, type: :system do
  let!(:ingestible) do
    create(:ingestible,
           markdown: "&&& Kalevala\n\nSome content here.",
           works_buffer: [{ title: 'Kalevala', content: 'Some content here.' }].to_json,
           works_buffer_updated_at: 1.minute.from_now,
           toc_buffer: 'yes || Kalevala ||  || poetry || fi || ')
  end

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_catalog_editor
  end

  it 'reveals the default mediating language select in the general tab and saves it' do
    visit edit_ingestible_path(ingestible)
    expect(page).to have_css('#general #ingestible_mediating_language', visible: :hidden, wait: 5)

    within('#general') { click_link I18n.t(:mediating_language) }
    expect(page).to have_css('#general #ingestible_mediating_language', visible: :visible, wait: 5)
    within('#general') do
      select I18n.t(:russian), from: 'ingestible_mediating_language'
      click_button I18n.t(:save)
    end

    expect(page).to have_css('#general #ingestible_mediating_language', visible: :visible, wait: 5)
    expect(ingestible.reload.mediating_language).to eq 'ru'
  end

  it 'reveals the per-text mediating language select in the TOC tab and saves it' do
    visit edit_ingestible_path(ingestible, tab: 'toc')
    expect(page).to have_css('#toc_div .toc-mediating-lang', visible: :hidden, wait: 5)

    within('#toc_div') { click_link I18n.t(:mediating_language) }
    expect(page).to have_css('#toc_div .toc-mediating-lang', visible: :visible, wait: 5)
    within('#toc_div') { find('.toc-mediating-lang').select(I18n.t(:german)) }

    # the TOC re-renders after the AJAX update, now showing the selected value without needing the link
    expect(page).to have_css('#toc_div .toc-mediating-lang option[selected][value="de"]', visible: :visible, wait: 5)
    expect(ingestible.reload.decode_toc.first[6]).to eq 'de'
  end
end
