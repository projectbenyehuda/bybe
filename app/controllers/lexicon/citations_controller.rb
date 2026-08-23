# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Citations
  class CitationsController < ApplicationController
    include LockLexEntryConcern
    include LinkCheckingConcern
    include TextLinksConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_citation, only: %i(edit update destroy reorder text_links add_text_link remove_text_link)
    before_action :set_person, only: %i(new create index)
    before_action :try_to_lock_record

    layout false

    def index; end

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
      # Captured before assign_attributes: link_broken? must be evaluated against the stored link
      link_was_broken = @citation.link_broken?
      old_link = @citation.link
      @citation.assign_attributes(lex_citation_params)
      new_subject_title = @citation.subject_title

      # If subject_title changed, move item to the bottom of new subject_title group
      if new_subject_title != old_subject_title
        max_seqno = @person.max_citation_seqno_by_subject_title(new_subject_title, exclude_citation_id: @citation.id)
        @citation.seqno = max_seqno + 1
      end

      if @citation.save
        if @citation.saved_change_to_link?
          check_link_synchronously(@citation, @citation.link,
                                   status_column: :link_http_status, checked_at_column: :link_checked_at)
          report_broken_link_fix(@citation, @person.entry, old_link) if link_was_broken
        end
        return
      end

      render :edit, status: :unprocessable_content
    end

    def destroy
      citation_id = @citation.id
      @citation.destroy!
      @person.entry&.remove_citation_from_checklist!(citation_id)
    end

    def text_links; end

    def add_text_link
      add_text_link_to(@citation, :text_links)
    end

    def remove_text_link
      remove_text_link_from(@citation, :text_links)
    end

    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based
      subject_title = params[:subject_title]

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

    def record_to_lock
      @person.lex_entry
    end

    # Only allow a list of trusted parameters through.
    def lex_citation_params
      params.expect(lex_citation: %i(title from_publication pages link backup_url manifestation_id subject
                                     lex_person_work_id notes))
    end
  end
end
