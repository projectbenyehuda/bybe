# frozen_string_literal: true

module Lexicon
  # Looks up the Wayback Machine snapshot of a link an editor has just saved and found broken.
  # A job rather than part of the save, because the lookup can take a minute (see WaybackLookup).
  class LookupArchiveUrlJob < ApplicationJob
    # The link may be deleted while the job waits in the queue; then there is nothing to do
    discard_on ActiveJob::DeserializationError

    # +record+ is a LexLink or LexCitation; +url+ is the broken URL it held when the job was enqueued.
    def perform(record, url)
      archive_url = WaybackLookup.call(url)
      return if archive_url.nil?

      columns = CheckExternalLinks::RECORD_COLUMNS.fetch(record.class.name)
      # The editor may have changed the link again while the lookup ran
      return unless record.reload[columns[:url]] == url

      record.update_column(columns[:archive_url], archive_url)
    end
  end
end
