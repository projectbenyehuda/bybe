# frozen_string_literal: true

module Admin
  # Controller to work with FeaturedAuthor records
  class FeaturedAuthorsController < ApplicationController
    before_action :require_editor
    before_action :set_featured_author, only: %i(show edit update destroy)

    def index
      @fcs = FeaturedAuthor.page(params[:page])
    end

    def new
      @fc = FeaturedAuthor.new
    end

    def create
      @fc = FeaturedAuthor.new(fa_params)
      @fc.person_id = params[:person_id]
      @fc.user = current_user

      if @fc.save
        redirect_to admin_featured_author_path(@fc), notice: t(:created_successfully)
      else
        render :new, status: :unprocessable_content
      end
    end

    def show; end

    def edit; end

    def update
      # We have few legacy records in DB where `user` is null, and it caused validation failures during update
      # To avoid this, we set user to current_user if it is empty
      @fc.user = current_user if @fc.user.nil?

      if @fc.update(fa_params)
        redirect_to admin_featured_author_path(@fc), notice: I18n.t(:updated_successfully)
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @fc.destroy
      redirect_to admin_featured_authors_path, notice: I18n.t(:deleted_successfully)
    end

    private

    def set_featured_author
      @fc = FeaturedAuthor.find(params[:id])
    end

    def fa_params
      params[:featured_author].permit(:title, :body)
    end
  end
end
