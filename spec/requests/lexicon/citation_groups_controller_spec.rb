# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::CitationGroupsController, type: :request do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }

  describe 'POST /lex/people/:person_id/citation_groups' do
    subject(:call) do
      post "/lex/people/#{person.id}/citation_groups", params: { lex_citation_group: { title: title } }, xhr: true
    end

    let(:title) { '  ספרים  ' }

    it 'creates the sub-heading, trimmed' do
      expect { call }.to change(LexCitationGroup, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(person.citation_groups.sole).to have_attributes(title: 'ספרים', seqno: 1)
    end

    context 'when a heading of that name already exists' do
      before { create(:lex_citation_group, person: person, title: 'ספרים') }

      it 'is rejected with the validation message' do
        expect { call }.not_to change(LexCitationGroup, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to be_present
      end
    end
  end

  describe 'PATCH /lex/citation_groups/:id' do
    subject(:call) do
      patch "/lex/citation_groups/#{group.id}", params: { lex_citation_group: { title: 'ספרי יובל' } }, xhr: true
    end

    let(:group) { create(:lex_citation_group, person: person, title: 'ספרים') }

    it 'renames the heading for every citation under it at once' do
      citation = create(:lex_citation, person: person, citation_group: group)
      expect(call).to eq(200)
      expect(group.reload.title).to eq('ספרי יובל')
      expect(citation.reload.citation_group.title).to eq('ספרי יובל')
    end
  end

  describe 'DELETE /lex/citation_groups/:id' do
    subject(:call) { delete "/lex/citation_groups/#{group.id}", xhr: true }

    let(:group) { create(:lex_citation_group, person: person) }
    let!(:citation) { create(:lex_citation, person: person, citation_group: group) }

    it 'removes the heading and returns its citations to the general list' do
      expect { call }.to change(LexCitationGroup, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(citation.reload.citation_group).to be_nil
      expect(citation.group_token).to be_nil
    end
  end

  describe 'POST /lex/citation_groups/:id/reorder' do
    subject(:call) { post "/lex/citation_groups/#{books.id}/reorder", params: { new_index: new_index }, xhr: true }

    let!(:books) { create(:lex_citation_group, person: person, title: 'ספרים') }
    let!(:articles) { create(:lex_citation_group, person: person, title: 'מאמרים') }
    let!(:festschrift) { create(:lex_citation_group, person: person, title: 'ספרי יובל') }

    let(:new_index) { 2 }

    it 'moves the heading and renumbers the rest' do
      expect(call).to eq(200)
      expect(person.reload.citation_groups.to_a).to eq([articles, festschrift, books])
      expect(person.citation_groups.map(&:seqno)).to eq([1, 2, 3])
    end

    context 'when the position is out of range' do
      let(:new_index) { 5 }

      it 'fails with bad request and changes nothing' do
        expect(call).to eq(400)
        expect(person.reload.citation_groups.to_a).to eq([books, articles, festschrift])
      end
    end
  end
end
