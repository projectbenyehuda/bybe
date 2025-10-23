# frozen_string_literal: true

require 'rails_helper'

describe Admin::FeaturedContentsController do
  include_context 'when editor logged in'

  describe '#index' do
    subject { get :index }

    before do
      create_list(:featured_content, 5)
    end

    it { is_expected.to be_successful }
  end

  describe '#new' do
    subject { get :new }

    it { is_expected.to be_successful }
  end

  describe '#create' do
    subject(:call) { post :create, params: { featured_content: featured_content_params } }

    let(:authority) { create(:authority) }
    let(:manifestation) { create(:manifestation) }

    let(:featured_content_params) do
      {
        title: title,
        body: Faker::Lorem.paragraph,
        external_link: Faker::Internet.url,
        authority_id: authority.id,
        manifestation_id: manifestation.id
      }
    end

    let(:created_featured_content) { FeaturedContent.order(id: :desc).first }

    context 'when params are valid' do
      let(:title) { Faker::Book.title }

      it 'creates record' do
        expect { call }.to change(FeaturedContent, :count).by(1)
        expect(call).to redirect_to admin_featured_content_path(created_featured_content)
        expect(created_featured_content).to have_attributes(featured_content_params)
        expect(created_featured_content.user).to eq current_user
      end
    end

    context 'when params are invalid' do
      let(:title) { nil }

      it 're-renders the new form' do
        expect { call }.not_to change(FeaturedContent, :count)
        expect(call).to have_http_status(:unprocessable_content)
        expect(call).to render_template(:new)
      end
    end
  end

  describe 'member actions' do
    let(:featured_content) { create(:featured_content) }

    describe '#show' do
      subject { get :show, params: { id: featured_content.id } }

      it { is_expected.to be_successful }
    end

    describe '#edit' do
      subject { get :edit, params: { id: featured_content.id } }

      it { is_expected.to be_successful }
    end

    describe '#update' do
      subject(:call) { patch :update, params: { id: featured_content.id, featured_content: featured_content_params } }

      let(:new_authority) { create(:authority) }
      let(:new_manifestation) { create(:manifestation) }

      context 'when params are valid' do
        let(:featured_content_params) do
          {
            title: 'new_title',
            body: 'new_body',
            external_link: 'https://test.com',
            authority_id: new_authority.id,
            manifestation_id: new_manifestation.id
          }
        end

        it 'updates record and redirects to show page' do
          expect(call).to redirect_to admin_featured_content_path(featured_content)
          featured_content.reload
          expect(featured_content).to have_attributes(featured_content_params)
        end
      end

      context 'when params are invalid' do
        let(:featured_content_params) { { title: '', body: '' } }

        it 're-renders the edit form' do
          expect(call).to have_http_status(:unprocessable_content)
          expect(call).to render_template(:edit)
        end
      end
    end

    describe '#destroy' do
      subject(:call) { delete :destroy, params: { id: featured_content.id } }

      before do
        featured_content
      end

      it 'removes record' do
        expect { call }.to change(FeaturedContent, :count).by(-1)
        expect(call).to redirect_to admin_featured_contents_path
      end
    end
  end
end
