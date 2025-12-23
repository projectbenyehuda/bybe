# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Links
  class LinksController < ApplicationController
    before_action :set_link, only: %i(edit update destroy)
    before_action :set_person, only: %i(new create index)

    layout false

    def index
      @lex_links = @person.links
    end

    def new
      @link = @person.links.build
    end

    def create
      @link = @person.links.build(lex_link_params)

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

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_link
      @link = LexLink.find(params[:id])
      @person = @link.item
    end

    # Only allow a list of trusted parameters through.
    def lex_link_params
      params.expect(lex_link: %i(url description))
    end
  end
end
