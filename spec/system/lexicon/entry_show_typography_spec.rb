# frozen_string_literal: true

require 'rails_helper'

describe 'Lexicon entry show typography', :js do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
  end

  let!(:person) { create(:lex_person, bio: 'Test biography content', works_count: 0, gender: :male) }
  let!(:entry) { create(:lex_entry, title: 'Test Person', lex_item: person, status: :published) }

  # a non-'original' work_type is what makes the works section emit an <h4> sub-heading,
  # and a non-blank subject is what makes the about section emit one
  let!(:work) { create(:lex_person_work, person: person, work_type: :translated, title: 'Some Work') }
  let!(:hebrew_citation) do
    create(:lex_citation, person: person, subject: 'Some Work', title: 'מאמר בעברית',
                          from_publication: 'כתב עת עברי', pages: '7', authors_count: 0)
  end
  let!(:latin_citation) do
    create(:lex_citation, person: person, subject: 'Some Work', title: 'An English Title',
                          from_publication: 'An English Journal', pages: '12', authors_count: 0)
  end

  def computed(selector, property)
    page.evaluate_script(
      "window.getComputedStyle(document.querySelector(#{selector.to_json})).#{property}"
    )
  end

  it 'gives the sub-headings 20px of space above them' do
    visit lexicon_entry_path(entry)

    expect(page).to have_css('#lexicon-works h4')
    expect(page).to have_css('#lexicon-about h4')

    expect(computed('#lexicon-works h4', 'marginTop')).to eq('20px')
    expect(computed('#lexicon-about h4', 'marginTop')).to eq('20px')
  end

  it 'renders the citations as a list with standard round bullets' do
    visit lexicon_entry_path(entry)

    expect(page).to have_css('#lexicon-about ul > li', count: 2)

    expect(computed('#lexicon-about ul', 'listStyleType')).to eq('disc')
    # the markers sit outside the list item, so the list needs inline start padding to show them
    expect(computed('#lexicon-about ul', 'paddingInlineStart').to_i).to be > 0
  end

  it 'keeps the bullet of a Latin-script citation aligned with the Hebrew ones' do
    visit lexicon_entry_path(entry)

    expect(page).to have_css('#lexicon-about ul > li', count: 2)

    # A direction: ltr on the <li> would put its marker on the opposite (left) side of the
    # list, so the two items' start edges would no longer coincide.
    directions = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('#lexicon-about ul > li'))
           .map(function (li) { return window.getComputedStyle(li).direction; })
    JS
    expect(directions).to all(eq('rtl'))

    # ...and the Latin text is still isolated so it reads left-to-right
    expect(page).to have_css('#lexicon-about li bdi[dir="ltr"]', text: 'An English Title')
  end
end
