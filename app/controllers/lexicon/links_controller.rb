# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Links
  class LinksController < ApplicationController
    before_action :set_link, only: %i(edit update destroy)
    before_action :set_entry, only: %i(new create index)

    layout false

    def index
      @links = @item.links
    end

    def new
      @link = @item.links.build
    end

    def create
      @link = @item.links.build(lex_link_params)

      return if @link.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      return if @link.update(lex_link_params)

      render :edit, status: :unprocessable_content
    end

    def destroy
      @link.destroy!
    end

    private

    def set_entry
      @entry = LexEntry.find(params[:entry_id])
      @item = @entry.lex_item
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_link
      @link = LexLink.find(params[:id])
      @item = @link.item
      @entry = @item.entry
    end

    # Only allow a list of trusted parameters through.
    def lex_link_params
      params.expect(lex_link: %i(url description))
    end
  end
end
