# frozen_string_literal: true

module Lexicon
  # Controller to work with People records in Lexicon
  class PeopleController < ::ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_lex_person, only: %i(edit update)

    layout false

    def autocomplete
      items = ElasticsearchAutocomplete.call(
        params[:term],
        LexPeopleAutocompleteIndex,
        %i(title)
      )
      render json: json_for_autocomplete(items, :title)
    end

    # GET /lex_people/new
    def new
      @lex_person = LexPerson.new
      @lex_person.build_entry(status: :draft)
    end

    # GET /lex_people/1/edit
    def edit; end

    # POST /lex_people or /lex_people.json
    def create
      @lex_person = LexPerson.new(lex_person_params)
      @lex_person.entry.status = :draft

      if @lex_person.save
        flash.notice = t('.success')
      else
        render :new, status: :unprocessable_content
      end
    end

    # PATCH/PUT /lex_people/1 or /lex_people/1.json
    def update
      @success = @lex_person.update(lex_person_params)
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_lex_person
      @lex_person = LexPerson.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def lex_person_params
      params.expect(
        lex_person: [
          :aliases,
          :authority_id,
          :copyrighted,
          :gender,
          :birthdate,
          :deathdate,
          :bio,
          :works,
          { entry_attributes: [:title] }
        ]
      )
    end
  end
end
