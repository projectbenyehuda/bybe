# frozen_string_literal: true

require 'rails_helper'

describe Lexicon::WorkGroupsController, type: :request do
  before do
    login_as_lexicon_editor
  end

  let(:person) { create(:lex_entry, :person).lex_item }

  describe 'POST /lex/people/:person_id/work_groups' do
    subject(:call) do
      post "/lex/people/#{person.id}/work_groups",
           params: { lex_person_work_group: { title: '  עיון  ', work_type: work_type } }, xhr: true
    end

    let(:work_type) { 'edited' }

    it 'creates the sub-heading in the given section, trimmed' do
      expect { call }.to change(LexPersonWorkGroup, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(person.work_groups.sole).to have_attributes(title: 'עיון', work_type: 'edited', seqno: 1)
    end

    context 'when the section does not exist' do
      let(:work_type) { 'bogus' }

      it 'is rejected with the validation message' do
        expect { call }.not_to change(LexPersonWorkGroup, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the section already has a sub-heading of that name' do
      before { create(:lex_person_work_group, person: person, title: 'עיון', work_type: 'edited') }

      it 'is rejected with the validation message' do
        expect { call }.not_to change(LexPersonWorkGroup, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to be_present
      end
    end
  end

  describe 'PATCH /lex/work_groups/:id' do
    let(:group) { create(:lex_person_work_group, person: person, title: 'עריכת תרגום') }
    let!(:work) { create(:lex_person_work, person: person, work_group: group) }

    it 'renames the sub-heading' do
      patch "/lex/work_groups/#{group.id}", params: { lex_person_work_group: { title: 'עריכת מקור' } }, xhr: true
      expect(response).to have_http_status(:ok)
      expect(group.reload.title).to eq('עריכת מקור')
    end

    it 'moves the sub-heading and its works to another section' do
      patch "/lex/work_groups/#{group.id}", params: { lex_person_work_group: { work_type: 'edited' } }, xhr: true
      expect(response).to have_http_status(:ok)
      expect(group.reload.work_type).to eq('edited')
      expect(work.reload).to have_attributes(work_type: 'edited', work_group: group)
    end
  end

  describe 'DELETE /lex/work_groups/:id' do
    let(:group) { create(:lex_person_work_group, person: person) }
    let!(:work) { create(:lex_person_work, person: person, work_group: group) }

    it 'removes the sub-heading but keeps its works' do
      expect { delete "/lex/work_groups/#{group.id}", xhr: true }.to change(LexPersonWorkGroup, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(work.reload.work_group).to be_nil
    end
  end

  describe 'POST /lex/work_groups/:id/reorder' do
    let!(:first) { create(:lex_person_work_group, person: person, title: 'שירה') }
    let!(:second) { create(:lex_person_work_group, person: person, title: 'עיון') }
    let!(:other_section) { create(:lex_person_work_group, person: person, title: 'עיון', work_type: 'edited') }

    it 'moves the sub-heading among those of its own section only' do
      post "/lex/work_groups/#{second.id}/reorder", params: { new_index: 0 }, xhr: true
      expect(response).to have_http_status(:ok)
      expect([second.reload.seqno, first.reload.seqno, other_section.reload.seqno]).to eq([1, 2, 1])
    end

    it 'rejects a position outside the section' do
      post "/lex/work_groups/#{second.id}/reorder", params: { new_index: 2 }, xhr: true
      expect(response).to have_http_status(:bad_request)
    end
  end
end
