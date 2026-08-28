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
    end

    private

    def set_lex_entry
      @lex_entry = LexEntry.find(params[:entry_id])
    end

    # Blank values remove the identifier, and an entry with no identifiers left stores NULL rather
    # than an empty hash -- the same treatment the verification workbench gives this form.
    def submitted_identifiers
      return nil unless params.key?(:external_identifiers)

      params.expect(external_identifiers: LexiconHelper::EXTERNAL_IDENTIFIER_LABELS.keys.map(&:to_sym))
            .to_h
            .compact_blank
            .presence
    end
  end
end
