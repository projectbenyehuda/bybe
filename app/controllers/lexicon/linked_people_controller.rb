# frozen_string_literal: true

module Lexicon
  # Controller for LexLinkedPerson records attached to LexPersonWork
  class LinkedPeopleController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(index create)
    before_action :set_linked_person, only: %i(destroy reorder)

    layout false

    def index
      @linked_people = @work
                       .linked_people
                       .preload(:person_entry)
                       .sort_by { |person| [person.seqno || 1_000_000, person.id] }
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
      work_id = params.fetch(:work_id).to_i

      if @work.id != work_id
        render plain: "work mismatch, actual: #{@work.id}, got: #{work_id}", status: :bad_request
        return
      end

      linked_people = @work.linked_people.sort_by { |person| [person.seqno || 1_000_000, person.id] }

      real_old_index = linked_people.index(@linked_person)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if old_index == new_index

      linked_people.delete_at(old_index)
      linked_people.insert(new_index, @linked_person)

      LexLinkedPerson.transaction do
        ordered_people_by_id = linked_people.index_by(&:id)
        linked_people.each_with_index do |person, index|
          temporary_seqno = -(index + 1)
          person.update_column(:seqno, temporary_seqno) if person.seqno != temporary_seqno
        end
        linked_people.map(&:id).each_with_index do |person_id, index|
          person = ordered_people_by_id.fetch(person_id)
          final_seqno = index + 1
          person.update_column(:seqno, final_seqno) if person.seqno != final_seqno
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
  end
end
