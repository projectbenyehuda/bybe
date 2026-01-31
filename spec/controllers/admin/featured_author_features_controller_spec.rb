# frozen_string_literal: true

require 'rails_helper'

describe Admin::FeaturedAuthorFeaturesController do
  include_context 'when editor logged in'

  let!(:featured_author) { create(:featured_author) }

  describe '#create' do
    subject(:call) do
      post :create, params: { featured_author_id: featured_author.id, featured_author_feature: feature_params }
    end

    context 'when params are invalid' do
      let(:feature_params) { { fromdate: nil, todate: nil } }

      it 'displays alert and redirects to featured author page' do
        expect { call }.not_to change(FeaturedAuthorFeature, :count)
        expect(call).to redirect_to admin_featured_author_path(featured_author)
        expect(flash.alert).to eq I18n.t('admin.featured_author_features.create.failed')
      end
    end

    context 'when params are valid' do
      let(:feature_params) { { fromdate: 5.days.ago.to_date, todate: 2.days.from_now.to_date } }

      it 'creates record and redirects to featured author page' do
        expect { call }.to change(FeaturedAuthorFeature, :count).by(1)
        feature = FeaturedAuthorFeature.order(id: :desc).first
        expect(feature).to have_attributes(feature_params)
        expect(call).to redirect_to admin_featured_author_path(featured_author)
        expect(flash.notice).to eq I18n.t(:created_successfully)
      end
    end
  end

  describe '#destroy' do
    subject(:call) { delete :destroy, params: { id: featured_author_feature.id } }

    let!(:featured_author_feature) { create(:featured_author_feature, featured_author: featured_author) }

    it 'deletes record and redirects to featured author show page' do
      expect { call }.to change(FeaturedAuthorFeature, :count).by(-1)
      expect(call).to redirect_to admin_featured_author_path(featured_author)
      expect(flash.notice).to eq I18n.t(:deleted_successfully)
    end
  end
end
