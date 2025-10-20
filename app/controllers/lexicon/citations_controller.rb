# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Citations
  class CitationsController < ApplicationController
    before_action :set_citation, only: %i(edit update destroy approve parse_again)
    before_action :set_entry, only: %i(new create index)

    layout false

    def index
      @lex_citations = @entry.lex_item.citations
    end

    def new
      @citation = @entry.lex_item.citations.build(status: :manual)
    end

    def create
      @citation = @entry.lex_item.citations.build(lex_citation_params.merge(status: :manual))

      unless @citation.save
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      unless @citation.update(lex_citation_params)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @citation.destroy!
    end

    def approve
      @citation.status_approved!
    end

    def parse_again
      c = Lexicon::ParseCitation.call(Nokogiri.HTML4("<li>#{@citation.raw}</li>"), nil)
      @citation.authors = c.authors
      @citation.title = c.title
      @citation.from_publication = c.from_publication
      @citation.pages = c.pages
      @citation.item = c.item
    end

    private

    def set_entry
      @entry = LexEntry.find(params[:entry_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_citation
      @citation = LexCitation.find(params[:id])
      @entry = @citation.item.entry
    end

    # Only allow a list of trusted parameters through.
    def lex_citation_params
      params.expect(lex_citation: %i(title from_publication authors pages link manifestation_id subject))
    end
  end
end
