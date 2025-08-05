# frozen_string_literal: true

# Controller to render list of all Lexicon entries
class LexEntriesController < ApplicationController
  before_action :set_lex_entry, only: %i(destroy)

  # GET /lex_entries or /lex_entries.json
  def index
    @lex_entries = LexEntry.all
  end

  # DELETE /lex_entries/1 or /lex_entries/1.json
  def destroy
    @lex_entry.destroy
    redirect_to lex_entries_url, notice: 'Lex entry was successfully destroyed.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_lex_entry
    @lex_entry = LexEntry.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def lex_entry_params
    params.require(:lex_entry).permit(:title, :status, :lex_person_id, :lex_publication_id)
  end
end
