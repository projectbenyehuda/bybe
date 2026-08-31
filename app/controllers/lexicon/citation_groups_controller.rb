# frozen_string_literal: true

module Lexicon
  # Manages the sub-headings of a person's general citations (ספרים, מאמרים, ...).
  # See LexCitationGroup. Editors work with these from the citations tab of the entry editor;
  # citations are moved between headings by dragging, or from the citation's own edit form.
  class CitationGroupsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_person, only: %i(create)
    before_action :set_group, only: %i(update destroy reorder)
    before_action :try_to_lock_record

    layout false

    # Every action answers a bare status and lets the caller reload the citations pane, rather than
    # rendering a fragment: adding, renaming or removing a heading reshuffles the whole list.
    def create
      @group = @person.citation_groups.build(citation_group_params)
      return head :created if @group.save

      render_errors(@group)
    end

    def update
      return head :ok if @group.update(citation_group_params)

      render_errors(@group)
    end

    # The heading goes; its citations stay, returning to the ungrouped general list
    # (has_many :citations, dependent: :nullify).
    def destroy
      @group.destroy!
      head :ok
    end

    # Repositions the heading among the person's other headings.
    def reorder
      new_index = params.fetch(:new_index).to_i # zero-based
      groups = @person.citation_groups.to_a
      old_index = groups.index(@group)

      if old_index.nil? || !new_index.between?(0, groups.size - 1)
        render plain: "cannot move heading to position #{new_index}", status: :bad_request
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
      @group = LexCitationGroup.find(params[:id])
      @person = @group.person
    end

    def record_to_lock
      @person.lex_entry
    end

    def citation_group_params
      params.expect(lex_citation_group: %i(title))
    end
  end
end
