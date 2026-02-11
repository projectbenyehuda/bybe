# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Person Works
  class PersonWorksController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(edit update destroy reorder)
    before_action :set_person, only: %i(new create index)
    after_action :sync_verification_checklist, only: %i(create update destroy reorder)

    layout false

    def index
      @lex_person_works = @person.works.includes(:publication)
    end

    def new
      @work = @person.works.build
    end

    def create
      @work = LexPersonWork.new(lex_person_work_params)

      # Assign seqno as the last position in the work_type group
      if @work.work_type.present?
        max_seqno = @person.max_work_seqno_by_type(@work.work_type)
        @work.seqno = max_seqno + 1
      end

      @work.person = @person

      return if @work.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      work_type = lex_person_work_params[:work_type]
      if work_type != @work.work_type && work_type.present?
        # if work type was changed we move item to the bottom of new work_type list
        max_seqno = @person.max_work_seqno_by_type(work_type)
        @work.seqno = max_seqno + 1
      end

      return if @work.update(lex_person_work_params)

      render :edit, status: :unprocessable_content
    end

    def destroy
      @work.destroy!
    end

    def reorder
      new_position = params[:new_pos].to_i - 1 # Convert from 1-based to 0-based

      # Get all works for the same person and work_type
      works = @person.works_by_type(@work.work_type).sort_by(&:seqno)

      old_position = works.index(@work)
      return head :ok if old_position.nil? || old_position == new_position

      works.delete_at(old_position)
      works.insert(new_position, @work)

      # Reassign seqno values
      works.each_with_index do |w, index|
        w.seqno = index + 1
        w.save(validate: false) if w.attribute_changed?(:seqno)
      end

      head :ok
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
      @lex_person_work_params ||= params.expect(
        lex_person_work: %i(
          title work_type publisher publication_date publication_place comment publication_id collection_id
        )
      )
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
