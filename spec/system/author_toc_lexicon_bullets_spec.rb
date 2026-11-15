# frozen_string_literal: true

require 'rails_helper'

# On the Authority TOC the lexicon block sits inside .author-works, whose `.author-works ul`
# rule (BY_styles_General.css) strips list bullets. The lexicon's works and citations must
# still render as bulleted lists, as they do on LexEntry#show, with Latin-script citations
# laid out left-to-right the same way.
describe 'Authority TOC lexicon list bullets', :js, type: :system do
  # Lazy `let` so the WebDriver skip can short-circuit before the DB + Chewy setup.
  let(:author) { create(:authority, name: 'Lexicon Author') }

  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?

    Chewy.strategy(:atomic) do
      create(:manifestation, title: 'Alpha Poem', status: :published, author: author, orig_lang: 'he',
                             markdown: 'The opening line of the Alpha poem.')
    end
    person = create(:lex_person, authority: author, bio: 'A lexicon biography.', works_count: 0)
    create(:lex_entry, title: author.name, lex_item: person, status: :published)
    create(:lex_person_work, person: person, work_type: :original, title: 'Some Work')
    create(:lex_citation, person: person, title: 'מאמר בעברית', from_publication: 'כתב עת עברי',
                          pages: '7', authors_count: 0)
    create(:lex_citation, person: person, title: 'An English Title', from_publication: 'An English Journal',
                          pages: '12', authors_count: 0)
  end

  after { Chewy.massacre }

  def computed(selector, property)
    page.evaluate_script(
      "window.getComputedStyle(document.querySelector(#{selector.to_json})).#{property}"
    )
  end

  it 'renders the works and citations with standard round bullets and room to show them' do
    visit authority_path(author)

    expect(page).to have_css('#lexicon-works ul > li', text: 'Some Work')
    expect(page).to have_css('#lexicon-about ul > li', count: 2)

    %w(#lexicon-works #lexicon-about).each do |section|
      expect(computed("#{section} ul", 'listStyleType')).to eq('disc')
      expect(computed("#{section} ul > li", 'listStyleType')).to eq('disc')
      # the markers sit outside the list item, so the list needs inline start padding to show them
      expect(computed("#{section} ul", 'paddingInlineStart').to_i).to be > 0
    end
  end

  it 'lays out a Latin-script citation left-to-right, with room for its bullet, as on LexEntry#show' do
    visit authority_path(author)

    expect(page).to have_css('#lexicon-about li[dir="ltr"]', text: 'An English Title')
    expect(page).to have_no_css('#lexicon-about li[dir="ltr"]', text: 'מאמר בעברית')

    expect(computed('#lexicon-about li[dir="ltr"]', 'textAlign')).to eq('left')
    # the marker sits outside the <li>, to its left, so the <li> needs room for it on that side
    gap = page.evaluate_script(<<~JS)
      (function () {
        var li = document.querySelector('#lexicon-about li[dir="ltr"]');
        return li.getBoundingClientRect().left - li.parentElement.getBoundingClientRect().left;
      })()
    JS
    expect(gap).to be > 10
  end
end
