# frozen_string_literal: true

# Implements methods required by LockRecordConcern to work with LexEntry records
module LockLexEntryConcern
  extend ActiveSupport::Concern

  include LockRecordConcern

  def redirect_if_locked_path
    lexicon_verification_index_path
  end

  def record_to_lock
    @lex_entry
  end
end
