# frozen_string_literal: true

# Implements methods required by LockRecordConcern to work with Ingestible records
module LockIngestibleConcern
  extend ActiveSupport::Concern

  include LockRecordConcern

  def record_to_lock
    @ingestible
  end

  def redirect_if_locked_path
    ingestibles_path
  end
end
