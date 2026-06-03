# frozen_string_literal: true

module Lexicon
  # Controller to work with Lexicon Links
  class LinksController < ApplicationController
    include LockLexEntryConcern
    include LinkCheckingConcern

    before_action do
      require_editor('edit_lexicon')
    end
    before_action :set_link, only: %i(edit update destroy)
    before_action :set_entry, only: %i(new create index)
    before_action :try_to_lock_record

    layout false

    def index
      @links = @item.links
    end

    def new
      @link = @item.links.build
    end

    def create
      @link = @item.links.build(lex_link_params)

      return if @link.save

      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      if @link.update(lex_link_params)
        # Re-check the link only when its URL actually changed, so a previously-broken
        # link (e.g. HTTP 403) is re-evaluated instead of keeping its stale status.
        if @link.saved_change_to_url?
          check_link_synchronously(@link, @link.url, status_column: :http_status, checked_at_column: :checked_at)
        end
        return
      end

      render :edit, status: :unprocessable_content
    end

    def destroy
      @link.destroy!
    end

    private

    def set_entry
      @entry = LexEntry.find(params[:entry_id])
      @item = @entry.lex_item
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_link
      @link = LexLink.find(params[:id])
      @item = @link.item
    end

    def record_to_lock
      @item.entry
    end

    # Only allow a list of trusted parameters through.
    def lex_link_params
      params.expect(lex_link: %i(url description))
    end
  end
end
