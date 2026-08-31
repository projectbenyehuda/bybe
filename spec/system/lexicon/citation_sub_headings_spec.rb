# frozen_string_literal: true

require 'rails_helper'

# Managing the general citation sub-headings (ספרים, מאמרים, ...) from the entry editor's
# citations tab. See LexCitationGroup.
RSpec.describe 'General citation sub-headings', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    login_as_lexicon_editor
  end

  let!(:person) { create(:lex_person, gender: :female) }
  let!(:entry) { create(:lex_entry, title: 'חוה שפירא', lex_item: person, status: :draft) }
  let!(:general) do
    create(:lex_citation, person: person, authors_count: 0, title: 'זרקור על דמות נעלמה', link: nil, seqno: 1)
  end

  def open_citations_tab
    visit "/lex/entries/#{entry.id}/edit"
    click_link_or_button I18n.t('lexicon.entries.edit.citations')
    expect(page).to have_css('#citations ul.citations-group', wait: 5)
  end

  def heading_titles
    all('#citation-headings .citation-heading-block .heading-title').map(&:text)
  end

  it 'adds a sub-heading from the citations tab' do
    open_citations_tab
    accept_prompt(with: 'ספרים') { find('a.add-citation-group').click }

    expect(page).to have_css('#citation-headings .citation-heading-block', text: 'ספרים', wait: 5)
    expect(person.citation_groups.reload.map(&:title)).to eq(['ספרים'])
  end

  context 'with an existing sub-heading' do
    let!(:group) { create(:lex_citation_group, person: person, title: 'ספרים') }
    let!(:grouped) do
      create(:lex_citation, person: person, citation_group: group, authors_count: 0,
                            title: 'מונוגרפיה על המחברת', link: nil, seqno: 1)
    end

    it 'shows the sub-heading verbatim, with its citation under it' do
      open_citations_tab

      within '#citation-headings .citation-heading-block' do
        expect(page).to have_css('h4', text: 'ספרים')
        expect(page).to have_css('ul.citations-group li', text: 'מונוגרפיה על המחברת')
      end
    end

    it 'renames the sub-heading' do
      open_citations_tab
      accept_prompt(with: 'ספרי יובל') do
        find('#citation-headings .rename-citation-group').click
      end

      expect(page).to have_css('#citation-headings h4', text: 'ספרי יובל', wait: 5)
      expect(group.reload.title).to eq('ספרי יובל')
    end

    it 'removes the sub-heading, keeping its citations in the general list' do
      open_citations_tab
      accept_confirm do
        find('#citation-headings .delete-citation-group').click
      end

      expect(page).to have_no_css('#citation-headings .citation-heading-block', wait: 5)
      expect(page).to have_css('ul.citations-group li', text: 'מונוגרפיה על המחברת')
      expect(grouped.reload.citation_group).to be_nil
    end

    it 'moves a citation into the sub-heading from its edit form' do
      open_citations_tab
      within('ul.citations-group.ungrouped-citations') do
        click_link_or_button I18n.t(:edit)
      end
      expect(page).to have_css('#generalDlg.show', wait: 5)

      within '#generalDlg' do
        select 'ספרים', from: 'lex_citation[lex_citation_group_id]'
        click_link_or_button I18n.t(:save)
      end

      expect(page).to have_css("ul.citations-group[data-group-token='heading:#{group.id}'] li",
                               text: 'זרקור על דמות נעלמה', wait: 5)
      expect(general.reload.citation_group).to eq(group)
    end

    context 'with a second sub-heading' do
      let!(:articles) { create(:lex_citation_group, person: person, title: 'מאמרים', seqno: 2) }

      # The drag itself is SortableJS, which Selenium cannot drive; what it posts is covered by
      # spec/requests/lexicon/citation_groups_controller_spec.rb. What matters here is that the tab lists the
      # headings in the editor's own order, and offers a handle to change it.
      it 'lists the sub-headings in their stored order, each with a drag handle' do
        open_citations_tab
        expect(heading_titles).to eq(%w(ספרים מאמרים))
        expect(page).to have_css('#citation-headings .heading-drag-handle', count: 2)

        articles.update!(seqno: 0)
        open_citations_tab
        expect(heading_titles).to eq(%w(מאמרים ספרים))
      end
    end
  end
end
