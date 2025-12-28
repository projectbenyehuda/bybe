# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Publications
  class PublicationsController < ApplicationController
    before_action :set_lex_publication, only: %i(edit update)
    before_action :set_person, only: %i(new create)

    layout false

    # GET /lex/people/:person_id/publications/new
    # GET /lex/publications/new
    def new
      @lex_publication = LexPublication.new
      @lex_publication.build_entry(status: :draft)
    end

    # GET /lex_publications/1/edit
    def edit; end

    # POST /lex/people/:person_id/publications or /lex/publications
    def create
      @lex_publication = LexPublication.new(lex_publication_params)
      @lex_publication.entry.status = :draft

      if @lex_publication.save
        # If created under a person, create the association
        @person.lex_people_items.create!(item: @lex_publication) if @person

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

    def set_person
      @person = LexPerson.find(params[:person_id]) if params[:person_id]
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
