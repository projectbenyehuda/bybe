# frozen_string_literal: true

module Lexicon
  # Controller to work with People records in Lexicon
  class PeopleController < ::ApplicationController
    before_action :set_lex_person, only: %i(edit update destroy)

    layout 'lexicon_backend'

    # GET /lex_people or /lex_people.json
    def index
      @lex_people = LexPerson.all
    end

    # GET /lex_people/new
    def new
      @lex_person = LexPerson.new
      @lex_person.build_entry(status: :manual)
    end

    # GET /lex_people/1/edit
    def edit; end

    # POST /lex_people or /lex_people.json
    def create
      @lex_person = LexPerson.new(lex_person_params)
      @lex_person.entry.status = :manual

      if @lex_person.save
        redirect_to lexicon_person_path(@lex_person), notice: t('.success')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /lex_people/1 or /lex_people/1.json
    def update
      if @lex_person.update(lex_person_params)
        redirect_to lexicon_person_path(@lex_person), notice: t('.success')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /lex_people/1 or /lex_people/1.json
    def destroy
      LexPerson.transaction do
        @lex_person.destroy
      end
      redirect_to lexicon_people_path, alert: t('.success')
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
          :birthdate,
          :deathdate,
          :bio,
          :works,
          :about,
          { entry_attributes: [:title] }
        ]
      )
    end
  end
end
