# frozen_string_literal: true

module Admin
  # Controller to work with FeaturedAuthorFeature records
  class FeaturedAuthorFeaturesController < ApplicationController
    before_action :require_editor

    def create
      fa = FeaturedAuthor.find(params[:featured_author_id])
      feature = fa.featurings.build(featured_author_feature_params)

      if feature.save
        redirect_to admin_featured_author_path(fa), notice: t(:created_successfully)
      else
        redirect_to admin_featured_author_path(fa), alert: t('.failed')
      end
    end

    def destroy
      faf = FeaturedAuthorFeature.find(params[:id])
      fa_id = faf.featured_author_id
      faf.destroy
      redirect_to admin_featured_author_path(fa_id), notice: t(:deleted_successfully)
    end

    private

    def featured_author_feature_params
      params.require(:featured_author_feature).permit(:fromdate, :todate)
    end
  end
end
