# frozen_string_literal: true

module Lexicon
  # Controller for LexCitationAuthor
  class CitationAuthorsController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_citation, only: %i(index create)
    before_action :set_author, only: %i(match update destroy)
    before_action :try_to_lock_record

    layout false

    def index
      # lex_file too: an author with no name of its own derives its display name from the
      # entry (see LexEntry#surname_first_title), which consults the file of a not-yet-ingested entry
      @authors = @citation.authors.preload(entry: :lex_file).sort_by(&:display_name)
    end

    def create
      @author = @citation.authors.build(author_params)

      # We use auto-completion to select an entry, so if an entry from db is selected we need to nullify the name
      if @author.lex_entry_id.present?
        @author.name = nil
      end

      unless @author.save
        # resetting value of possibly selected lex_entry_id if record is invalid (probaly non-unique value)
        @author.lex_entry_id = nil
        status = :unprocessable_content
      else
        status = :ok
      end

      render status: status
    end

    # Modal offering to link a plaintext author imported from a legacy PHP file to an existing
    # person entry, pre-filled with the name the match was found by (see LexCitationAuthor.normalize_name).
    def match; end

    # Links the author to the chosen person entry. The imported name is deliberately left untouched,
    # so the citation keeps displaying it as "lastname, firstname" exactly as the legacy file had it.
    # An entry-linked author may not also carry a link, so any leftover link is dropped -- the same
    # thing ParseCitations#update_link does when it links an author during ingestion.
    def update
      # The record is looked up rather than the id assigned straight through, so a submission naming
      # an entry that does not exist is rejected here. Two ordinary cases reach this: the
      # autocomplete clears its hidden id field as soon as the editor edits the text, and the
      # autocomplete index can still offer an entry that has since been deleted (a stale document
      # outlives the row it described, since the index is only pruned when a destroy runs through
      # the model). Without the lookup the second case sails past validation -- `entry` is nil, so
      # `entry_must_be_person` never runs -- and fails on the lex_entries foreign key with a 500.
      @author.assign_attributes(entry: LexEntry.find_by(id: match_params[:lex_entry_id]), link: nil)

      if @author.entry.nil?
        @author.errors.add(:lex_entry_id, :entry_not_found)
      elsif @author.save
        return head :ok
      end

      render :match, status: :unprocessable_content
    end

    def destroy
      @author.destroy!
    end

    private

    def author_params
      params.expect(lex_citation_author: %i(name link lex_entry_id))
    end

    # Only the entry reference is accepted: the modal's autocomplete box also submits the title the
    # editor searched by, but the imported name must survive the match unchanged.
    def match_params
      params.expect(lex_citation_author: %i(lex_entry_id))
    end

    def set_citation
      @citation = LexCitation.find(params[:citation_id])
    end

    def set_author
      @author = LexCitationAuthor.find(params[:id])
      @citation = @author.citation
    end

    def record_to_lock
      @citation.person.lex_entry
    end
  end
end
