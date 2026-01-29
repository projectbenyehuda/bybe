# frozen_string_literal: true

require 'rails_helper'

describe 'Author LexCitations card' do
  before do
    author.update(lex_person: lex_person)
  end

  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:author) do
    create(:authority, :published, name: 'Test Author', uncollected_works_collection: uncollected_collection)
  end
  let(:lex_entry) { create(:lex_entry, :person, status: 'draft') }
  let(:lex_person) { lex_entry.lex_item }

  context 'with general citations' do
    let!(:citation) { create(:lex_citation, person: lex_person, person_work: nil, title: 'About the Author') }

    it 'displays citations card with general citations' do
      visit authority_path(author)

      within('.by-card-v02.left-side-card-v02', text: I18n.t(:lex_citations_about_author)) do
        expect(page).to have_content('About the Author')
      end
    end
  end

  context 'with work-specific citation only' do
    let(:lex_person_work) { create(:lex_person_work, person: lex_person) }
    let!(:work_citation) do
      create(:lex_citation, person: lex_person, person_work: lex_person_work, title: 'About a Work')
    end

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
