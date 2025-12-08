# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Citations
  class CitationsController < ApplicationController
    before_action :set_citation, only: %i(edit update destroy approve)
    before_action :set_person, only: %i(new create index)

    layout false

    def index
      @lex_citations = @person.citations
    end

    def new
      @citation = @person.citations.build(status: :manual)
    end

    def create
      @citation = @person.citations.build(lex_citation_params.merge(status: :manual))

      return if @citation.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      return if @citation.update(lex_citation_params)

      render :edit, status: :unprocessable_content
    end

    def destroy
      @citation.destroy!
    end

    def approve
      @citation.status_approved!
    end

    private

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_citation
      @citation = LexCitation.find(params[:id])
      @person = @citation.person
    end

    # Only allow a list of trusted parameters through.
    def lex_citation_params
      params.expect(lex_citation: %i(title from_publication authors pages link manifestation_id subject))
    end
  end
end
