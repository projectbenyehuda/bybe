# frozen_string_literal: true

module Lexicon
  # Controller to render list of all Lexicon entries
  class EntriesController < ApplicationController
    before_action except: %i(show) do |c|
      c.require_editor('edit_lexicon')
    end
    before_action :set_lex_entry, only: %i(show edit destroy)

    layout 'lexicon_backend', except: %i(show)

    # GET /lex_entries or /lex_entries.json
    def index
      @lex_entries = LexEntry.where.not(lex_item: nil).page(params[:page])
    end

    def show
      unless @lex_entry.status_published?
        require_editor('edit_lexicon')
      end
    end

    def edit
      @edit_properties_path = if @lex_entry.lex_item.is_a?(LexPerson)
                                edit_lexicon_person_path(@lex_entry.lex_item)
                              elsif @lex_entry.lex_item.is_a?(LexPublication)
                                edit_lexicon_publication_path(@lex_entry.lex_item)
                              else
                                raise "Unexpected lex_entry type: #{@lex_entry.lex_item.class}"
                              end

      @tab = params[:tab] || 'properties'
    end

    def destroy
      @lex_entry.destroy
      redirect_to lexicon_entries_url, alert: t('.success')
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
