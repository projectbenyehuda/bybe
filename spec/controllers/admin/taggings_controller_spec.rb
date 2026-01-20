# frozen_string_literal: true

require 'rails_helper'

describe Admin::TaggingsController do
  include_context 'when editor logged in', 'moderate_tags'

  # Make route helpers available in controller specs for view rendering
  routes { Rails.application.routes }

  describe '#index' do
    subject { get :index, params: params }

    let(:params) { {} }

    before do
      create_list(:tagging, 3, status: :approved)
      create_list(:tagging, 2, status: :pending)
    end

    it { is_expected.to be_successful }

    it 'assigns taggings' do
      subject
      expect(assigns(:taggings).count).to eq(3) # default filter is approved
    end

    context 'when filtering by status' do
      let(:params) { { status: 'pending' } }

      it 'filters taggings by status' do
        subject
        expect(assigns(:taggings).count).to eq(2)
      end
    end

    context 'when searching by item title' do
      let!(:manifestation) { create(:manifestation, title: 'על תורת השיר העברי') }
      let!(:searchable_tagging) { create(:tagging, taggable: manifestation, status: :approved) }

      let(:params) { { item_q: 'תורת השיר', status: '' } }

      it 'finds taggings by item title' do
        subject
        expect(assigns(:taggings)).to include(searchable_tagging)
      end
    end

    context 'when searching by tag name' do
      let(:tag) do
        name = "פואטיקה-#{SecureRandom.hex(4)}"
        # Tag automatically creates a primary tag_name via callback
        create(:tag, name: name)
      end
      let!(:searchable_tagging) { create(:tagging, tag: tag, status: :approved) }

      let(:params) { { tag_q: 'פואטיק', status: '' } }

      it 'finds taggings by tag name' do
        subject
        expect(assigns(:taggings)).to include(searchable_tagging)
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { id: tagging.id } }

    let(:tagging) { create(:tagging) }

    it { is_expected.to be_successful }

    it 'assigns tagging' do
      subject
      expect(assigns(:tagging)).to eq(tagging)
    end
  end

  describe '#destroy' do
    subject(:call) { delete :destroy, params: { id: tagging.id } }

    let!(:tagging) { create(:tagging) }

    it 'destroys tagging' do
      expect { call }.to change(Tagging, :count).by(-1)
      expect(call).to redirect_to admin_taggings_path
    end
  end

  describe 'permission check' do
    context 'when user does not have moderate_tags permission' do
      let(:editor_without_permission) { create(:user, editor: true) }

      before do
        session[:user_id] = editor_without_permission.id
      end

      it 'redirects to home page' do
        get :index
        expect(response).to redirect_to('/')
      end
    end
  end
end
