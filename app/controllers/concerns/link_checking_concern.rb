# frozen_string_literal: true

# Shared synchronous external-link (re-)checking for Lexicon controllers that let editors
# edit a URL (LexLink and LexCitation). On a URL change the controller re-checks the link
# and stores the fresh HTTP status on the record, exposing a toast for the JS response.
# Also reports corrections of previously-broken links to Monday (see #report_broken_link_fix).
module LinkCheckingConcern
  extend ActiveSupport::Concern

  private

  # Re-checks +url+ synchronously and stores the resulting HTTP status on +record+. A broken link's
  # Internet Archive snapshot is looked up in the background (see Lexicon::LookupArchiveUrlJob):
  # the lookup can take a minute, too long to hold up the editor's save.
  # A blank URL clears the stored status without making a network request.
  # Sets @link_check_performed / @link_toast_type / @link_toast_message for the JS view.
  def check_link_synchronously(record, url)
    columns = Lexicon::CheckExternalLinks::RECORD_COLUMNS.fetch(record.class.name)
    if url.blank?
      record.update_columns(columns[:status] => nil, columns[:checked_at] => nil, columns[:unverifiable] => false,
                            columns[:archive_url] => nil)
      return
    end

    result = Lexicon::CheckExternalLinks.new.check_url(url)
    record.update_columns(columns[:status] => result.status, columns[:checked_at] => Time.current,
                          columns[:unverifiable] => result.unverifiable?, columns[:archive_url] => nil)
    Lexicon::LookupArchiveUrlJob.perform_later(record, url) if result.broken?
    @link_check_performed = true
    @link_toast_type, @link_toast_message = link_toast_for(result)
    # flash (not flash.now) is intentional: the JS response triggers a full page reload in the
    # verification view, and the toast must survive into the reloaded request.
    flash[:link_check_toast_type] = @link_toast_type
    flash[:link_check_toast_message] = @link_toast_message
  end

  # Files a Monday report when an editor replaces a link that link-checking had flagged as
  # broken, so the correction can be tracked alongside the other verification reports.
  # Limited to entries still in the migration verification workflow: routine link maintenance
  # on published entries is not part of migration verification and is not reported.
  # A failed report never blocks the save; it only raises a toast (see the update.js.erb views).
  def report_broken_link_fix(record, entry, old_link)
    return unless entry&.needs_verification?

    result = Lexicon::MondayReport.call(
      entry: entry,
      report_type: :fixed_broken_link,
      current_url: lexicon_verification_url(entry),
      record: record,
      old_link: old_link
    )
    return if result[:success]

    Rails.logger.error("#{self.class.name}: Monday broken-link report failed: #{result[:error]}")
    @monday_report_failed = true
    @monday_toast_message = t('lexicon.verification.monday.report_error')
  end

  def link_toast_for(result)
    status = result.status
    if result.unverifiable?
      ['warning', t('lexicon.verification.broken_link.unverifiable_toast')]
    elsif status.nil?
      ['error', t('lexicon.verification.broken_link.inaccessible')]
    elsif status < 400
      ['success', t('lexicon.verification.broken_link.now_accessible')]
    else
      ['error', t('lexicon.verification.broken_link.still_broken', status: status)]
    end
  end
end
