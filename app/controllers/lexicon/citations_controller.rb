# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Citations
  class CitationsController < ApplicationController
    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_citation, only: %i(edit update destroy approve reorder)
    before_action :set_person, only: %i(new create index)

    layout false

    def index
      @lex_citations = @person.citations.preload(authors: { person: :entry })
    end

    def new
      @citation = @person.citations.build
    end

    def create
      @citation = @person.citations.build(lex_citation_params)

      # Assign seqno as the last position in the subject_title group
      @citation.seqno = @person.max_citation_seqno_by_subject_title(@citation.subject_title) + 1

      return if @citation.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      old_subject_title = @citation.subject_title
      @citation.assign_attributes(lex_citation_params)
      new_subject_title = @citation.subject_title

      # If subject_title changed, move item to the bottom of new subject_title group
      if new_subject_title != old_subject_title
        max_seqno = @person.max_citation_seqno_by_subject_title(new_subject_title, exclude_citation_id: @citation.id)
        @citation.seqno = max_seqno + 1
      end

      return if @citation.save

      render :edit, status: :unprocessable_content
    end

    def destroy
      @citation.destroy!
    end

    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based
      subject_title = params.fetch(:subject_title)

      if @citation.subject_title != subject_title
        render plain: "subject_title mismatch, actual: '#{@citation.subject_title}', got: '#{subject_title}'",
               status: :bad_request
        return
      end

      # Get all citations for the same person and subject_title
      citations = @person.citations_by_subject_title(subject_title).sort_by(&:seqno)

      real_old_index = citations.index(@citation)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if old_index == new_index

      citations.delete_at(old_index)
      citations.insert(new_index, @citation)

      # Reassign seqno values
      citations.each_with_index do |c, index|
        c.seqno = index + 1
        c.save(validate: false) if c.attribute_changed?(:seqno)
      end

      head :ok
    end

    private

    def set_person
      @person = LexPerson.find(params[:person_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_citation
      @citation = LexCitation.find(params[:id])
      @person = @citation.person
    end

    # Only allow a list of trusted parameters through.
    def lex_citation_params
      params.expect(lex_citation: %i(title from_publication pages link manifestation_id subject lex_person_work_id))
    end
  end
end
