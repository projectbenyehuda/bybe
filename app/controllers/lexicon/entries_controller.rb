# frozen_string_literal: true

module Lexicon
  # Controller to render list of all Lexicon entries
  class EntriesController < ApplicationController
    before_action :set_lex_entry, only: %i(show)

    layout 'lexicon_backend'

    # GET /lex_entries or /lex_entries.json
    def index
      @lex_entries = LexEntry.all.page(params[:page])
    end

    def show
      if @lex_entry.lex_item.is_a?(LexPerson)
        redirect_to lexicon_person_path(@lex_entry.lex_item)
      elsif @lex_entry.lex_item.is_a?(LexPublication)
        redirect_to lexicon_publication_path(@lex_entry.lex_item)
      else
        redirect_to action: :index, alert: t('.unsupported_entry_type')
      end
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_lex_entry
      @lex_entry = LexEntry.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_entry_params
      params.expect(lex_entry: %i(title status lex_person_id lex_publication_id))
    end
  end
end
