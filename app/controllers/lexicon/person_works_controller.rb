# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Person Works
  class PersonWorksController < ApplicationController
    include LockLexEntryConcern
    include TextLinksConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(edit update destroy reorder title_links add_title_link remove_title_link
                                      comment_links add_comment_link remove_comment_link)
    before_action :set_person, only: %i(new create index)

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

      if @work.save
        @person.entry&.add_work_to_checklist!(@work.id)
        return
      end

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
      work_id = @work.id
      @work.destroy!
      @person.entry&.remove_work_from_checklist!(work_id)
    end

    def title_links; end

    def add_title_link
      add_text_link_to(@work, :title_links)
    end

    def remove_title_link
      remove_text_link_from(@work, :title_links)
    end

    def comment_links; end

    def add_comment_link
      add_text_link_to(@work, :comment_links)
    end

    def remove_comment_link
      remove_text_link_from(@work, :comment_links)
    end

    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based
      work_type = params.fetch(:work_type)

      if @work.work_type != work_type
        render plain: "work_type mismatch, actual: '#{@work.work_type}', got: '#{work_type}'", status: :bad_request
        return
      end

      # Get all works for the same person and work_type
      works = @person.works_by_type(work_type).sort_by(&:seqno)

      real_old_index = works.index(@work)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if old_index == new_index

      works.delete_at(old_index)
      works.insert(new_index, @work)

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

    def record_to_lock
      @person.lex_entry
    end

    # Only allow a list of trusted parameters through.
    def lex_person_work_params
      @lex_person_work_params ||= params.expect(
        lex_person_work: %i(
          title work_type publisher publication_date publication_place comment publication_id collection_id
        )
      )
    end
  end
end
