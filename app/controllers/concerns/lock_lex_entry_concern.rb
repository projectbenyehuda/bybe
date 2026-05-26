# frozen_string_literal: true

# Logic to lock LexEntry objects, to be included in related controllers
module LockLexEntryConcern
  extend ActiveSupport::Concern

  def try_to_lock_lex_entry
    entry = lex_entry_to_lock
    return unless entry
    return if entry.obtain_lock(current_user)

    error_msg = t('lexicon.entries.entry_locked', user: entry.locked_by_user.name)

    respond_to do |format|
      format.html do
        if request.xhr?
          render html: "<p class='text-danger'>#{ERB::Util.html_escape(error_msg)}</p>".html_safe,
                 status: :unprocessable_content, layout: false
        else
          flash.alert = error_msg
          redirect_to lexicon_entries_path
        end
      end
      format.js { render js: "alert(#{error_msg.to_json});" }
      format.json { render json: { error: error_msg }, status: :locked }
    end
  end

  private

  def lex_entry_to_lock
    @lex_entry
  end
end
