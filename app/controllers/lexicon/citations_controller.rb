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

      # Assign seqno as the last position in the heading's group
      @citation.seqno = @person.max_citation_seqno_by_group_token(@citation.group_token) + 1

      return if @citation.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      old_group_token = @citation.group_token
      # Captured before assign_attributes: link_broken? must be evaluated against the stored link
      link_was_broken = @citation.link_broken?
      old_link = @citation.link
      @citation.assign_attributes(lex_citation_params)
      new_group_token = @citation.group_token

      # If the heading changed, move item to the bottom of the new group
      if new_group_token != old_group_token
        max_seqno = @person.max_citation_seqno_by_group_token(new_group_token, exclude_citation_id: @citation.id)
        @citation.seqno = max_seqno + 1
      end

      if @citation.save
        if @citation.saved_change_to_link?
          check_link_synchronously(@citation, @citation.link,
                                   status_column: :link_http_status, checked_at_column: :link_checked_at,
                                   unverifiable_column: :link_unverifiable)
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

    # Repositions a citation within its heading's group, or -- when to_group_token names a
    # different one -- moves it to a position in that group. Only the general buckets (the
    # ungrouped citations and the general sub-headings) can be dragged between: moving a citation
    # under a work changes what it is about, which is the edit form's business, not a drag's.
    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      old_index = params.fetch(:old_index).to_i # zero-based
      from_token = params[:group_token].presence
      to_token = params.key?(:to_group_token) ? params[:to_group_token].presence : from_token

      if @citation.group_token != from_token
        render plain: "group_token mismatch, actual: '#{@citation.group_token}', got: '#{from_token}'",
               status: :bad_request
        return
      end

      source = @person.citations_by_group_token(from_token).sort_by(&:seqno)
      real_old_index = source.index(@citation)
      if old_index != real_old_index
        render plain: "old_index mismatch, actual: #{real_old_index}, got: #{old_index}", status: :bad_request
        return
      end

      return head :ok if from_token == to_token && old_index == new_index

      source.delete_at(old_index)

      if from_token == to_token
        target = source
      else
        # Both ends have to be general buckets. Dragging a citation out of a work's list would
        # leave it both about a work and under a general sub-heading, which LexCitation forbids --
        # and renumber saves without validating, so nothing downstream would catch it.
        return unless general_bucket?(from_token) && general_bucket?(to_token)

        target_group = resolve_general_group(to_token)
        return if performed?

        # Read the target list before reassigning: @citation is a separate instance from the copy
        # @person.citations holds, so the list would otherwise contain it twice.
        target = @person.citations_by_group_token(to_token).sort_by(&:seqno)
        @citation.citation_group = target_group
        renumber(source)
      end

      target.insert(new_index.clamp(0, target.size), @citation)
      renumber(target)

      head :ok
    end

    private

    # Whether a token names one of the general buckets a citation may be dragged in or out of:
    # the ungrouped general citations, or a general sub-heading. A work's list, and a heading still
    # carrying an unresolved legacy subject, are not -- and a work titled 'heading:something' must
    # not pass for one either, hence the exact 'heading:<id>' match. Renders the refusal itself.
    def general_bucket?(token)
      return true if token.nil? || LexCitation.heading_token_group_id(token).present?

      render plain: "'#{token}' is not a general citation heading", status: :bad_request
      false
    end

    # The LexCitationGroup a drag target token names, or nil for the ungrouped general citations.
    # Renders an error (leaving #performed? true) when it names no heading of this person.
    def resolve_general_group(token)
      return nil if token.nil?

      group = @person.citation_groups.find_by(id: LexCitation.heading_token_group_id(token))
      render plain: "unknown citation group '#{token}'", status: :bad_request if group.nil?
      group
    end

    # Writes 1..n into the seqno of a group's citations. Saves any citation with a pending change,
    # not only a changed seqno: a citation dragged into another group keeps its position number as
    # often as not, and its new lex_citation_group_id still has to be written.
    def renumber(citations)
      citations.each_with_index do |citation, index|
        citation.seqno = index + 1
        citation.save(validate: false) if citation.changed?
      end
    end

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
                                     lex_person_work_id lex_citation_group_id notes))
    end
  end
end
