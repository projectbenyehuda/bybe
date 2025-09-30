# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Publications
  class PublicationsController < ApplicationController
    before_action :set_lex_publication, only: %i(edit update destroy)

    layout 'lexicon_backend'

    # GET /lex_publications or /lex_publications.json
    def index
      @lex_publications = LexPublication.all
    end

    # GET /lex_publications/new
    def new
      @lex_publication = LexPublication.new
      @lex_publication.build_entry(status: :manual)
    end

    # GET /lex_publications/1/edit
    def edit; end

    # POST /lex_publications or /lex_publications.json
    def create
      @lex_publication = LexPublication.new(lex_publication_params)
      @lex_publication.entry.status = :manual

      if @lex_publication.save
        redirect_to lexicon_publication_path(@lex_publication), notice: t('.success')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /lex_publications/1 or /lex_publications/1.json
    def update
      if @lex_publication.update(lex_publication_params)
        redirect_to lexicon_publication_path(@lex_publication), notice: t('.success')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /lex_publications/1 or /lex_publications/1.json
    def destroy
      @lex_publication.destroy
      redirect_to lexicon_publications_url, alert: t('.success')
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
