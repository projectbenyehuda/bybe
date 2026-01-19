# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Author LexCitations display', type: :request do
  let(:uncollected_collection) { create(:collection, :uncollected) }
  let(:author) { create(:authority, :published, uncollected_works_collection: uncollected_collection) }

  context 'when author has lex_person with general citations' do
    let(:lex_entry) { create(:lex_entry, :person, status: 'draft') }
    let(:lex_person) { lex_entry.lex_item }
    let!(:citation1) { create(:lex_citation, person: lex_person, item: nil, title: 'General Citation') }
    let!(:citation2) do
      lex_person_work = create(:lex_person_work, person: lex_person)
      create(:lex_citation, person: lex_person, item: lex_person_work, title: 'Work Citation')
    end

    before do
      author.update(lex_person: lex_person)
    end

    it 'displays only general citations (item nil)' do
      get authority_path(author)
      expect(response.body).to include('General Citation')
      expect(response.body).not_to include('Work Citation')
      expect(response.body).to include(I18n.t(:lex_citations_about_author))
    end
  end

  context 'when author has no general citations or no lex_person' do
    it 'does not display citations card when author has no general citations' do
      get authority_path(author)
      expect(response.body).not_to include(I18n.t(:lex_citations_about_author))
    end

    it 'does not display citations card when author has no lex_person' do
      author_without_lex = create(:authority, :published, uncollected_works_collection: uncollected_collection)
      get authority_path(author_without_lex)
      expect(response.body).not_to include(I18n.t(:lex_citations_about_author))
    end
  end
end
