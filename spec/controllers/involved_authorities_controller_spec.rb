# frozen_string_literal: true

require 'rails_helper'

describe InvolvedAuthoritiesController do
  include_context 'when editor logged in', :edit_catalog

  let!(:manifestation) { create(:manifestation) }
  let!(:collection) { create(:collection, manifestations: [manifestation]) }

  describe '#index' do
    subject(:call) { get :index, params: { item_type: item.class.name, item_id: item.id } }

    let(:item) { manifestation.expression.work }

    it { is_expected.to be_successful }
  end

  describe '#create' do
    subject(:call) do
      post :create,
           params: {
             item_type: item.class.name,
             item_id: item.id,
             involved_authority: { authority_id: authority.id, role: role }
           }
    end

    let!(:authority) { create(:authority) }
    let(:role) { 'translator' }
    let(:item) { collection }

    it 'creates record' do
      expect { call }.to change(InvolvedAuthority, :count).by(1)
      expect(call).to be_successful

      ia = InvolvedAuthority.order(id: :desc).first
      expect(ia).to have_attributes(item: item, role: role, authority: authority)
    end

    context 'when validation fails' do
      # translator role is not allowed for works
      let(:item) { manifestation.expression.work }

      it 'fails to create record' do
        expect { call }.not_to change(InvolvedAuthority, :count)
        expect(call).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe '#destroy' do
    subject(:call) { delete :destroy, params: { id: involved_authority.id }, format: :js }

    let!(:involved_authority) { create(:involved_authority, item: item, role: :editor) }

    context 'when Expression authority' do
      let(:item) { manifestation.expression }

      it 'destroys record' do
        expect { call }.to change(InvolvedAuthority, :count).by(-1)
        expect(call).to be_successful
      end
    end

    context 'when Work authority' do
      let(:item) { manifestation.expression.work }

      it 'destroys record' do
        expect { call }.to change(InvolvedAuthority, :count).by(-1)
        expect(call).to be_successful
      end
    end

    context 'when Collection authority' do
      let(:item) { create(:collection, manifestations: [manifestation]) }

      it 'destroys record' do
        expect { call }.to change(InvolvedAuthority, :count).by(-1)
        expect(call).to be_successful
      end
    end
  end
end
