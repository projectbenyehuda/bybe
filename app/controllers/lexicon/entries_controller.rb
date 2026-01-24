# frozen_string_literal: true

module Lexicon
  # Controller to render list of all Lexicon entries
  class EntriesController < ApplicationController
    before_action except: %i(show list) do |c|
      c.require_editor('edit_lexicon')
    end
    before_action :set_lex_entry, only: %i(show edit update destroy)

    layout 'lexicon_backend', except: %i(show list)

    # GET /lex_entries or /lex_entries.json
    def index
      @lex_entries = LexEntry.where.not(lex_item: nil)

      # Filter by status if provided
      if params[:status].present?
        @lex_entries = @lex_entries.where(status: params[:status])
      end

      # Filter by title substring if provided (case-insensitive)
      if params[:title].present?
        @lex_entries = @lex_entries.where('LOWER(title) LIKE LOWER(?)', "%#{params[:title]}%")
      end

      @lex_entries = @lex_entries.page(params[:page])
    end

    def list
      @page_title = "#{t('.page_title')} - #{t(:project_ben_yehuda)}"
      @pagetype = :lex_entries
      @header_partial = 'lexicon/entries/list_top'

      # Handle sorting
      @sort = params[:sort_by].presence || 'alphabetical_asc'

      @lex_entries = LexEntry.where.not(lex_item: nil).where(status: :published)

      # Apply sorting based on the sort parameter
      @lex_entries = case @sort
                     when 'alphabetical_asc'
                       @lex_entries.order('lex_entries.title ASC')
                     when 'alphabetical_desc'
                       @lex_entries.order('lex_entries.title DESC')
                     when 'birth_year_asc'
                       # Join only LexPerson entries and sort by birthdate, NULLS LAST
                       @lex_entries
                     .joins("LEFT JOIN lex_people ON lex_entries.lex_item_type = 'LexPerson' " \
                            'AND lex_entries.lex_item_id = lex_people.id')
                     .order(Arel.sql('CASE WHEN lex_people.birthdate IS NULL THEN 1 ELSE 0 END, ' \
                                     'lex_people.birthdate ASC'))
                     when 'birth_year_desc'
                       # Join only LexPerson entries and sort by birthdate descending, NULLS LAST
                       @lex_entries
                     .joins("LEFT JOIN lex_people ON lex_entries.lex_item_type = 'LexPerson' " \
                            'AND lex_entries.lex_item_id = lex_people.id')
                     .order(Arel.sql('CASE WHEN lex_people.birthdate IS NULL THEN 1 ELSE 0 END, ' \
                                     'lex_people.birthdate DESC'))
                     when 'death_year_asc'
                       # Join only LexPerson entries and sort by deathdate, NULLS LAST
                       @lex_entries
                     .joins("LEFT JOIN lex_people ON lex_entries.lex_item_type = 'LexPerson' " \
                            'AND lex_entries.lex_item_id = lex_people.id')
                     .order(Arel.sql('CASE WHEN lex_people.deathdate IS NULL THEN 1 ELSE 0 END, ' \
                                     'lex_people.deathdate ASC'))
                     when 'death_year_desc'
                       # Join only LexPerson entries and sort by deathdate descending, NULLS LAST
                       @lex_entries
                     .joins("LEFT JOIN lex_people ON lex_entries.lex_item_type = 'LexPerson' " \
                            'AND lex_entries.lex_item_id = lex_people.id')
                     .order(Arel.sql('CASE WHEN lex_people.deathdate IS NULL THEN 1 ELSE 0 END, ' \
                                     'lex_people.deathdate DESC'))
                     else
                       # Default to alphabetical ascending
                       @lex_entries.order('lex_entries.title ASC')
                     end

      @lex_entries = @lex_entries.page(params[:page])
      @total = @lex_entries.total_count
    end

    def show
      return if @lex_entry.status_published?

      require_editor('edit_lexicon')
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

    def update
      if @lex_entry.update(lex_entry_params)
        render json: { success: true, status: @lex_entry.status }
      else
        render json: { success: false, errors: @lex_entry.errors.full_messages }, status: :unprocessable_entity
      end
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
