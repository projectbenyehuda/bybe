# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author LexCitations card', :js, type: :system do
  before do
    skip 'WebDriver not available or misconfigured' unless webdriver_available?
    author.update(lex_person: lex_person)
  end

  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:author) do
    create(:authority, :published, name: 'Test Author', uncollected_works_collection: uncollected_collection)
  end
  let(:lex_entry) { create(:lex_entry, :person, status: 'draft') }
  let(:lex_person) { lex_entry.lex_item }

  context 'with general citations' do
    let!(:citation) { create(:lex_citation, person: lex_person, item: nil, title: 'About the Author') }

    it 'displays citations card with general citations' do
      visit authority_path(author)

      within('.by-card-v02.left-side-card-v02', text: I18n.t(:lex_citations_about_author)) do
        expect(page).to have_content('About the Author')
      end
    end
  end

  context 'with work-specific citation only' do
    let(:lex_person_work) { create(:lex_person_work, person: lex_person) }
    let!(:work_citation) { create(:lex_citation, person: lex_person, item: lex_person_work, title: 'About a Work') }

    it 'does not display citations card' do
      visit authority_path(author)
      expect(page).not_to have_content(I18n.t(:lex_citations_about_author))
    end
  end

  context 'without general citations' do
    it 'does not display citations card' do
      visit authority_path(author)
      expect(page).not_to have_content(I18n.t(:lex_citations_about_author))
    end
  end
end
