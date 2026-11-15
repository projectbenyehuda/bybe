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

      # Assign seqno as the last position in the work_type group. A sub-heading decides the
      # work type (see LexPersonWork#reconcile_work_group_and_type).
      work_type = @work.work_group&.work_type || @work.work_type
      @work.seqno = @person.max_work_seqno_by_type(work_type) + 1 if work_type.present?

      @work.person = @person

      if @work.save
        @person.entry&.add_work_to_checklist!(@work.id)
        return
      end

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      @work.assign_attributes(lex_person_work_params)
      if @work.work_type_changed? || @work.lex_person_work_group_id_changed?
        # A work moved to another section or sub-heading goes to the bottom of its new list. A
        # sub-heading decides the section (see LexPersonWork#reconcile_work_group_and_type).
        group_changed = @work.lex_person_work_group_id_changed? && @work.work_group.present?
        work_type = group_changed ? @work.work_group.work_type : @work.work_type
        @work.seqno = @person.max_work_seqno_by_type(work_type, exclude_work_id: @work.id) + 1
      end

      return if @work.save

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

    # Moves a work within its bucket -- the ungrouped works of a section, or one sub-heading's works
    # -- or, given to_work_type, into another bucket of any section. Moving a work changes its work
    # type and sub-heading to the target bucket's.
    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based
      from = [params.fetch(:work_type), params[:group_id].presence&.to_i]
      to = params.key?(:to_work_type) ? [params[:to_work_type], params[:to_group_id].presence&.to_i] : from

      actual = [@work.work_type, @work.lex_person_work_group_id]
      if actual != from
        render plain: "bucket mismatch, actual: #{actual}, got: #{from}", status: :bad_request
        return
      end

      source = @person.works_in_bucket(*from)
      real_old_index = source.index(@work)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if from == to && old_index == new_index

      source.delete_at(old_index)
      if from == to
        target = source
      else
        target_group = to.last && @person.work_groups.find_by(id: to.last)
        if !LexPersonWork.work_types.key?(to.first) || (to.last && target_group&.work_type != to.first)
          render plain: "no such section: #{to}", status: :bad_request
          return
        end

        # Read the target list before reassigning @work's bucket, or it could pick @work up as
        # well and list it twice.
        target = @person.works_in_bucket(*to)
        @work.assign_attributes(work_type: to.first, work_group: target_group)
        renumber(source)
      end

      target.insert(new_index.clamp(0, target.size), @work)
      renumber(target)

      head :ok
    end

    private

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    # Saved without validation, as before sub-headings existed: only seqno, and for a moved work its
    # bucket, change here. The bucket was checked above, so the work's type and group agree.
    def renumber(works)
      works.each_with_index do |w, index|
        w.seqno = index + 1
        w.save(validate: false) if w.changed?
      end
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
          lex_person_work_group_id
        )
      )
    end
  end
end
