# frozen_string_literal: true

module Lexicon
  # Controller for LexLinkedPerson records attached to LexPersonWork
  class LinkedPeopleController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_work, only: %i(index create)
    before_action :set_linked_person, only: %i(destroy)

    layout false

    def index
      @linked_people = @work.linked_people.preload(:person_entry).sort_by(&:name)
    end

    def create
      @linked_person = @work.linked_people.build(linked_person_params)

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
