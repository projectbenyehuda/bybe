# frozen_string_literal: true

module Lexicon
  # Controller for LexCitationAuthor
  class CitationAuthorsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_citation, only: %i(index create)
    before_action :set_author, only: %i(destroy)
    before_action :try_to_lock_record

    layout false

    def index
      @authors = @citation.authors.preload(:entry).sort_by(&:display_name)
    end

    def create
      @author = @citation.authors.build(author_params)

      # We use auto-completion to select an entry, so if an entry from db is selected we need to nullify the name
      if @author.lex_entry_id.present?
        @author.name = nil
      end

      unless @author.save
        # resetting value of possibly selected lex_entry_id if record is invalid (probaly non-unique value)
        @author.lex_entry_id = nil
        status = :unprocessable_content
      else
        status = :ok
      end

      render status: status
    end

    def destroy
      @author.destroy!
    end

    private

    def author_params
      params.expect(lex_citation_author: %i(name link lex_entry_id))
    end

    def set_citation
      @citation = LexCitation.find(params[:citation_id])
    end

    def set_author
      @author = LexCitationAuthor.find(params[:id])
      @citation = @author.citation
    end

    def record_to_lock
      @citation.person.lex_entry
    end
  end
end