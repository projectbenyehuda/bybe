# frozen_string_literal: true

module Lexicon
  # Controller for LexCitationAuthor
  class CitationAuthorsController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_citation, only: %i(index create)
    before_action :set_author, only: %i(destroy)

    layout false

    def index
      @authors = @citation.authors.preload(person: :entry).sort_by(&:display_name)
    end

    def create
      @author = @citation.authors.build(author_params)

      # We use auto-completion to select a person, so if a person from db is selected we need to nullify the name
      if @author.lex_person_id.present?
        @author.name = nil
      end

      @author.save
      render status: @author.new_record? ? :unprocessable_content : :ok
    end

    def destroy
      @author.destroy!
    end

    private

    def author_params
      params.expect(lex_citation_author: %i(name link lex_person_id))
    end

    def set_citation
      @citation = LexCitation.find(params[:citation_id])
    end

    def set_author
      @author = LexCitationAuthor.find(params[:id])
      @citation = @author.citation
    end
  end
end