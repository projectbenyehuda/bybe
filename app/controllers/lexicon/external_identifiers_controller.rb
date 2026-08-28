# frozen_string_literal: true

module Lexicon
  # Controller for a LexEntry's authority control identifiers (its external_identifiers JSON
  # column), edited from the "authority control" tab of the entry edit page.
  # Mounted on lexicon/entries/:entry_id/external_identifiers.
  class ExternalIdentifiersController < ApplicationController
    include LockLexEntryConcern

    before_action do
      require_editor('edit_lexicon')
    end

    before_action :set_lex_entry
    before_action :try_to_lock_record

    # Returns content of the authority control panel
    def show
      # Normally loaded as a fragment (entry edit tab pane), but the panel is also reachable by
      # direct navigation, which needs the layout and its JS assets -- without them the remote
      # form degrades to a plain HTML submit.
      render layout: request.xhr? ? false : 'lexicon_backend'
    end

    def update
      @success = @lex_entry.update(external_identifiers: submitted_identifiers)

      respond_to do |format|
        format.js
        # What a JS-less page does with a remote form. Without this the submit is processed as
        # HTML, finds no update.html template, and blows up *after* the column has been written.
        format.html do
          flash[:alert] = @lex_entry.errors.full_messages.to_sentence unless @success
          redirect_to lexicon_entry_external_identifiers_path(@lex_entry)
        end
      end
    end

    private

    def set_lex_entry
      @lex_entry = LexEntry.find(params[:entry_id])
    end

    # Blank values remove the identifier, and an entry with no identifiers left stores NULL rather
    # than an empty hash -- the same treatment the verification workbench gives this form.
    #
    # A request with no external_identifiers key at all is not "clear them": every field posts, even
    # when empty, so its absence means a malformed request. Let expect raise ParameterMissing (400)
    # rather than silently wiping the column.
    def submitted_identifiers
      params.expect(external_identifiers: LexiconHelper::EXTERNAL_IDENTIFIER_LABELS.keys.map(&:to_sym))
            .to_h
            .compact_blank
            .presence
    end
  end
end
