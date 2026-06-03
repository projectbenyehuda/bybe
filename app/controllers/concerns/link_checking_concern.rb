# frozen_string_literal: true

# Shared synchronous external-link (re-)checking for Lexicon controllers that let editors
# edit a URL (LexLink and LexCitation). On a URL change the controller re-checks the link
# and stores the fresh HTTP status on the record, exposing a toast for the JS response.
#
# Records differ in their column names, so the caller passes them in:
#   - LexLink:     status_column: :http_status,      checked_at_column: :checked_at
#   - LexCitation: status_column: :link_http_status, checked_at_column: :link_checked_at
module LinkCheckingConcern
  extend ActiveSupport::Concern

  private

  # Re-checks +url+ synchronously and stores the resulting HTTP status on +record+.
  # A blank URL clears the stored status without making a network request.
  # Sets @link_check_performed / @link_toast_type / @link_toast_message for the JS view.
  def check_link_synchronously(record, url, status_column:, checked_at_column:)
    if url.blank?
      record.update_columns(status_column => nil, checked_at_column => nil)
      return
    end

    status = Lexicon::CheckExternalLinks.new.check_url(url)
    record.update_columns(status_column => status, checked_at_column => Time.current)
    @link_check_performed = true
    @link_toast_type, @link_toast_message = link_toast_for(status)
    # flash (not flash.now) is intentional: the JS response triggers a full page reload in the
    # verification view, and the toast must survive into the reloaded request.
    flash[:link_check_toast_type] = @link_toast_type
    flash[:link_check_toast_message] = @link_toast_message
  end

  def link_toast_for(status)
    if status.nil?
      ['error', t('lexicon.verification.broken_link.inaccessible')]
    elsif status < 400
      ['success', t('lexicon.verification.broken_link.now_accessible')]
    else
      ['error', t('lexicon.verification.broken_link.still_broken', status: status)]
    end
  end
end
