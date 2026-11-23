# frozen_string_literal: true

module Lexicon
  # Manages the sub-headings within the work-type sections of a person's works list (e.g. עיון under
  # the original works). See LexPersonWorkGroup. Editors work with these from the works tab of the
  # entry editor; works are moved between sub-headings by dragging, or from the work's own edit form.
  class WorkGroupsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_person, only: %i(create)
    before_action :set_group, only: %i(update destroy reorder)
    before_action :try_to_lock_record

    layout false

    # Every action answers a bare status and lets the caller reload the works pane, rather than
    # rendering a fragment: adding, moving or removing a sub-heading reshuffles the whole list.
    def create
      @group = @person.work_groups.build(work_group_params)
      return head :created if @group.save

      render_errors(@group)
    end

    # Renames the sub-heading, or moves it -- works and all -- to another work-type section.
    def update
      return head :ok if @group.update(work_group_params)

      render_errors(@group)
    end

    # The sub-heading goes; its works stay, returning to the ungrouped list of their section
    # (has_many :works, dependent: :nullify).
    def destroy
      @group.destroy!
      head :ok
    end

    # Repositions the sub-heading among the other sub-headings of its section.
    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      groups = @person.work_groups.select { |g| g.work_type == @group.work_type }
      old_index = groups.index(@group)

      if old_index.nil? || !new_index.between?(0, groups.size - 1)
        render plain: "cannot move sub-heading to position #{new_index}", status: :bad_request
        return
      end

      groups.delete_at(old_index)
      groups.insert(new_index, @group)
      groups.each_with_index do |group, index|
        group.update_column(:seqno, index + 1) if group.seqno != index + 1
      end

      head :ok
    end

    private

    def render_errors(group)
      render plain: group.errors.full_messages.to_sentence, status: :unprocessable_content
    end

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    def set_group
      @group = LexPersonWorkGroup.find(params[:id])
      @person = @group.person
    end

    def record_to_lock
      @person.lex_entry
    end

    def work_group_params
      params.expect(lex_person_work_group: %i(title work_type))
    end
  end
end
