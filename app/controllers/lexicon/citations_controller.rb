# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Citations
  class CitationsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_citation, only: %i(edit update destroy reorder)
    before_action :set_person, only: %i(new create index)
    before_action :try_to_lock_lex_entry, only: %i(create edit update destroy reorder)

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
      @citation.assign_attributes(lex_citation_params)
      new_subject_title = @citation.subject_title

      # If subject_title changed, move item to the bottom of new subject_title group
      if new_subject_title != old_subject_title
        max_seqno = @person.max_citation_seqno_by_subject_title(new_subject_title, exclude_citation_id: @citation.id)
        @citation.seqno = max_seqno + 1
      end

      if @citation.save
        check_link_synchronously if @citation.saved_change_to_link?
        return
      end

      render :edit, status: :unprocessable_content
    end

    def destroy
      @citation.destroy!
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

    def lex_entry_to_lock
      @person&.entry
    end

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

    def check_link_synchronously
      if @citation.link.blank?
        @citation.update_column(:link_http_status, nil)
        return
      end

      status = CheckExternalLinks.new.check_url(@citation.link)
      @citation.update_column(:link_http_status, status)
      @link_check_performed = true
      @link_toast_type, @link_toast_message = link_toast_for(status)
      # rubocop:disable Rails/ActionControllerFlashBeforeRender
      flash[:link_check_toast_type] = @link_toast_type
      flash[:link_check_toast_message] = @link_toast_message
      # rubocop:enable Rails/ActionControllerFlashBeforeRender
    end

    def link_toast_for(status)
      if status.nil?
        ['warning', t('lexicon.verification.broken_link.check_failed')]
      elsif status < 400
        ['success', t('lexicon.verification.broken_link.now_accessible')]
      else
        ['error', t('lexicon.verification.broken_link.still_broken', status: status)]
      end
    end
  end
end
