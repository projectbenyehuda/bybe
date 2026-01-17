# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Person Works
  class PersonWorksController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(edit update destroy)
    before_action :set_person, only: %i(new create index)
    after_action :sync_verification_checklist, only: %i(create update destroy)

    layout false

    def index
      @lex_person_works = @person.works.includes(:publication)
    end

    def new
      @work = @person.works.build
    end

    def create
      @work = @person.works.build(lex_person_work_params)

      return if @work.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      return if @work.update(lex_person_work_params)

      render :edit, status: :unprocessable_content
    end

    def destroy
      @work.destroy!
    end

    private

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_work
      @work = LexPersonWork.find(params[:id])
      @person = @work.person
    end

    # Only allow a list of trusted parameters through.
    def lex_person_work_params
      params.expect(lex_person_work: %i(title work_type publisher publication_date publication_place comment))
    end

    # Sync verification checklist when works are added/updated/deleted
    def sync_verification_checklist
      # Get the entry for this person if it exists and is being verified
      entry = @person.entry
      return if entry&.verification_progress.blank?

      entry.sync_works_checklist!
    end
  end
end
