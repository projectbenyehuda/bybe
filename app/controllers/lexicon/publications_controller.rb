# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Publications
  class PublicationsController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_lex_publication, only: %i(edit update)

    layout false

    # GET /lex_publications/new
    def new
      @lex_publication = LexPublication.new
      @lex_publication.build_entry(status: :draft)
    end

    # GET /lex_publications/1/edit
    def edit; end

    # POST /lex_publications or /lex_publications.json
    def create
      @lex_publication = LexPublication.new(lex_publication_params)
      @lex_publication.entry.status = :draft

      if @lex_publication.save
        flash.notice = t('.success')
      else
        render :new, status: :unprocessable_content
      end
    end

    # PATCH/PUT /lex_publications/1 or /lex_publications/1.json
    def update
      @lex_publication.update(lex_publication_params)
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_lex_publication
      @lex_publication = LexPublication.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_publication_params
      params.expect(
        lex_publication: [
          :description,
          :toc,
          :az_navbar,
          { entry_attributes: [:title] }
        ]
      )
    end
  end
end
