# frozen_string_literal: true

require 'rails_helper'

# Regression test for Sefaria linker references (e.g. the footnotes of /read/72197) that looked
# like plain text. Sefaria's linker.v3.js creates each reference anchor with
# `a.style.all = "unset"`, which wipes every link style via inline CSS. The external linker is
# not loaded in tests, so we inject an anchor exactly the way it does and check that our
# stylesheet still makes it look like a link.
describe 'Manifestation#read with Sefaria linker references', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:text) do
    Chewy.strategy(:atomic) do
      create(:manifestation, orig_lang: 'he', status: :published,
                             markdown: "פסקה עם הערה[^1]\n\n[^1]: ראה שיר השירים, פרק ב' פסוק ח'.")
    end
  end

  after { Chewy.massacre }

  # Mimics the anchor built by the linker's createATag (linker.v3.js).
  def inject_sefaria_ref
    page.execute_script(<<~JS)
      var p = document.querySelector('#actualtext .footnotes li p');
      var a = document.createElement('a');
      a.target = '_blank';
      a.textContent = 'שיר השירים, פרק ב';
      a.className = 'sefaria-ref';
      a.style.all = 'unset';
      a.style.cursor = 'pointer';
      a.href = 'https://www.sefaria.org/Song_of_Songs.2.8';
      p.insertBefore(a, p.firstChild);
    JS
    expect(page).to have_css('#actualtext .footnotes a.sefaria-ref')
  end

  def computed_style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector('#{selector}')).#{property}")
  end

  it 'renders the reference in link color despite the inline all:unset' do
    visit manifestation_path(text)
    expect(page).to have_css('#actualtext .footnotes li p')
    inject_sefaria_ref

    ref_color = computed_style('a.sefaria-ref', 'color')
    expect(ref_color).to eq('rgb(102, 2, 72)') # #660248, the site's link color
    expect(ref_color).not_to eq(computed_style('#actualtext .footnotes li p', 'color'))
  end

  it 'applies the link hover style to the reference' do
    visit manifestation_path(text)
    expect(page).to have_css('#actualtext .footnotes li p')
    inject_sefaria_ref

    find('a.sefaria-ref').hover
    expect(page).to have_css('a.sefaria-ref:hover')
    expect(computed_style('a.sefaria-ref', 'backgroundColor')).to eq('rgb(217, 205, 213)') # #d9cdd5
    expect(computed_style('a.sefaria-ref', 'textDecorationLine')).to eq('underline')
  end
end
