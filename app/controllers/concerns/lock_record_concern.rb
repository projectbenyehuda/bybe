# frozen_string_literal: true

# To be used in Controllers for actions related to editing records implementing Lockable concern
module LockRecordConcern
  extend ActiveSupport::Concern

  # This method tries to lock record. If record is already locked by different user it redirects to
  # path returned by redirect_if_locked_path method.
  # Should be used as `before_action` hook
  def try_to_lock_record
    rec = record_to_lock
    return if rec.obtain_lock(current_user)

    respond_to do |format|
      flash.alert = t(
        'lock_record.record_locked',
        user: rec.locked_by_user.name,
        model_name: rec.class.model_name.human
      )

      format.html { redirect_to redirect_if_locked_path }
      format.js { render js: "window.location.href = '#{redirect_if_locked_path}';" }
    end
  end

  # This method should be implemented in controller and should return record to be locked
  # @return record to be locked
  def record_to_lock
    raise 'not implemented!'
  end

  # @return path where we should redirect user if object is locked by different user
  def redirect_if_locked_path
    raise 'not implemented!'
  end
end
