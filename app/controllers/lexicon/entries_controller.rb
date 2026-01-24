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

      # Extract filter parameters
      @name_filter = params[:name_filter].to_s.strip
      @genders = Array(params[:ckb_genders]).compact_blank
      @birth_year_from = params[:birth_year_from].to_i if params[:birth_year_from].present?
      @birth_year_to = params[:birth_year_to].to_i if params[:birth_year_to].present?
      @death_year_from = params[:death_year_from].to_i if params[:death_year_from].present?
      @death_year_to = params[:death_year_to].to_i if params[:death_year_to].present?

      # Determine if person-specific filters are active
      @person_filters_active = @genders.any? || @birth_year_from.present? || @birth_year_to.present? ||
                               @death_year_from.present? || @death_year_to.present?

      # Start with base scope
      @lex_entries = LexEntry.includes(:lex_item).where.not(lex_item: nil).where(status: :published)

      # Calculate gender facets (before applying gender filter)
      @gender_facet = calculate_gender_facets

      # Apply filters
      @lex_entries = apply_filters(@lex_entries)

      # Build @filters array for pills
      @filters = build_filter_pills

      # Apply sorting
      @lex_entries = apply_sorting(@lex_entries)

      # Paginate
      @lex_entries = @lex_entries.page(params[:page])
      @total = @lex_entries.total_count

      # Respond to AJAX
      respond_to do |format|
        format.html
        format.js
      end
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

    def apply_filters(scope)
      # Name substring filter
      if @name_filter.present?
        scope = scope.where('LOWER(lex_entries.title) LIKE LOWER(?)', "%#{@name_filter}%")
      end

      # If person filters active, only show LexPerson entries
      if @person_filters_active
        scope = scope.where(lex_item_type: 'LexPerson')
        scope = scope.joins('INNER JOIN lex_people ON lex_entries.lex_item_id = lex_people.id')
      end

      # Gender filter (person-specific)
      if @genders.any?
        # Convert gender strings to enum integer values
        gender_values = @genders.map { |g| LexPerson.genders[g] }.compact
        scope = scope.where('lex_people.gender IN (?)', gender_values) if gender_values.any?
      end

      # Birth year range filter (person-specific)
      if @birth_year_from.present? || @birth_year_to.present?
        scope = scope.where('lex_people.birthdate IS NOT NULL')
        if @birth_year_from.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.birthdate, 1, 4) AS SIGNED) >= ?', @birth_year_from)
        end
        if @birth_year_to.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.birthdate, 1, 4) AS SIGNED) <= ?', @birth_year_to)
        end
      end

      # Death year range filter (person-specific)
      if @death_year_from.present? || @death_year_to.present?
        scope = scope.where('lex_people.deathdate IS NOT NULL')
        if @death_year_from.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.deathdate, 1, 4) AS SIGNED) >= ?', @death_year_from)
        end
        if @death_year_to.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.deathdate, 1, 4) AS SIGNED) <= ?', @death_year_to)
        end
      end

      scope
    end

    def apply_sorting(scope)
      # For date-based sorting, ensure we have the JOIN if not already added
      needs_join = @sort.include?('year') && !@person_filters_active

      if needs_join
        scope = scope.joins("LEFT JOIN lex_people ON lex_entries.lex_item_type = 'LexPerson' " \
                            'AND lex_entries.lex_item_id = lex_people.id')
      end

      case @sort
      when 'alphabetical_asc'
        scope.order('lex_entries.title ASC')
      when 'alphabetical_desc'
        scope.order('lex_entries.title DESC')
      when 'birth_year_asc'
        scope.order(Arel.sql('CASE WHEN lex_people.birthdate IS NULL THEN 1 ELSE 0 END, lex_people.birthdate ASC'))
      when 'birth_year_desc'
        scope.order(Arel.sql('CASE WHEN lex_people.birthdate IS NULL THEN 1 ELSE 0 END, lex_people.birthdate DESC'))
      when 'death_year_asc'
        scope.order(Arel.sql('CASE WHEN lex_people.deathdate IS NULL THEN 1 ELSE 0 END, lex_people.deathdate ASC'))
      when 'death_year_desc'
        scope.order(Arel.sql('CASE WHEN lex_people.deathdate IS NULL THEN 1 ELSE 0 END, lex_people.deathdate DESC'))
      else
        scope.order('lex_entries.title ASC')
      end
    end

    def build_filter_pills
      filters = []

      if @name_filter.present?
        filters << [t('lexicon.entries.list.filters.name_contains', name: @name_filter), 'name_filter', :text]
      end

      @genders.each do |gender|
        filters << [t("lexicon.entries.list.filters.gender_#{gender}"), "ckb_genders_#{gender}", :checkbox]
      end

      if @birth_year_from.present?
        filters << [t('lexicon.entries.list.filters.birth_from', year: @birth_year_from), 'birth_year_from', :text]
      end

      if @birth_year_to.present?
        filters << [t('lexicon.entries.list.filters.birth_to', year: @birth_year_to), 'birth_year_to', :text]
      end

      if @death_year_from.present?
        filters << [t('lexicon.entries.list.filters.death_from', year: @death_year_from), 'death_year_from', :text]
      end

      if @death_year_to.present?
        filters << [t('lexicon.entries.list.filters.death_to', year: @death_year_to), 'death_year_to', :text]
      end

      filters
    end

    def calculate_gender_facets
      # Build a scope with all filters EXCEPT gender
      scope = LexEntry.where.not(lex_item: nil).where(status: :published)
                      .where(lex_item_type: 'LexPerson')
                      .joins('INNER JOIN lex_people ON lex_entries.lex_item_id = lex_people.id')

      # Apply name filter
      if @name_filter.present?
        scope = scope.where('LOWER(lex_entries.title) LIKE LOWER(?)', "%#{@name_filter}%")
      end

      # Apply birth year filters
      if @birth_year_from.present? || @birth_year_to.present?
        scope = scope.where('lex_people.birthdate IS NOT NULL')
        if @birth_year_from.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.birthdate, 1, 4) AS SIGNED) >= ?', @birth_year_from)
        end
        if @birth_year_to.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.birthdate, 1, 4) AS SIGNED) <= ?', @birth_year_to)
        end
      end

      # Apply death year filters
      if @death_year_from.present? || @death_year_to.present?
        scope = scope.where('lex_people.deathdate IS NOT NULL')
        if @death_year_from.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.deathdate, 1, 4) AS SIGNED) >= ?', @death_year_from)
        end
        if @death_year_to.present?
          scope = scope.where('CAST(SUBSTRING(lex_people.deathdate, 1, 4) AS SIGNED) <= ?', @death_year_to)
        end
      end

      # Group by gender and count
      counts = scope.group('lex_people.gender').count

      # Convert integer keys to string keys and return as hash
      facet = {}
      LexPerson.genders.each do |gender_name, gender_value|
        facet[gender_name] = counts[gender_value] || 0
      end

      facet
    end
  end
end
