# frozen_string_literal: true

module Lexicon
  # Controller for LexLinkedPerson records attached to LexPersonWork
  class LinkedPeopleController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(index create)
    before_action :set_linked_person, only: %i(destroy reorder)
    before_action :try_to_lock_record

    layout false

    def index
      @linked_people = @work.linked_people.preload(:person_entry).sort_by(&:sort_value)
    end

    def create
      @linked_person = @work.linked_people.build(linked_person_params)
      @linked_person.seqno = (@work.linked_people.maximum(:seqno) || 0) + 1

      unless @linked_person.save
        @linked_person.person_lex_entry_id = nil if @linked_person.errors[:person_entry].present?
        status = :unprocessable_content
      else
        status = :ok
      end

      render status: status
    end

    def destroy
      @linked_person.destroy!
    end

    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based

      linked_people = @work.linked_people.sort_by(&:sort_value)

      real_old_index = linked_people.index(@linked_person)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if old_index == new_index

      linked_people.delete_at(old_index)
      linked_people.insert(new_index, @linked_person)

      LexLinkedPerson.transaction do
        linked_people.each_with_index do |person, index|
          new_seqno = index + 1
          person.update_column(:seqno, new_seqno) if person.seqno != new_seqno
        end
      end

      head :ok
    end

    private

    def linked_person_params
      params.expect(lex_linked_person: %i(name link_type person_lex_entry_id))
    end

    def set_work
      @work = LexPersonWork.find(params[:work_id])
    end

    def set_linked_person
      @linked_person = LexLinkedPerson.find(params[:id])
      @work = @linked_person.person_work
    end

    def record_to_lock
      @work.person.lex_entry
    end
  end
end
