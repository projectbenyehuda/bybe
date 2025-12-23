# frozen_string_literal: true

module PeriodicalsHelper
  # Formats work links for display, including periodical issue information if available
  # @param manifestations [Array<Manifestation>] the manifestations to format
  # @return [String] HTML-safe string of work links separated by semicolons
  def format_periodical_works(manifestations)
    worksbuf = manifestations.map do |m|
      periodical_issue = m.volumes.find(&:periodical_issue?)
      work_link = link_to(
        m.expression.title + (m.expression.translation ? ' / ' + m.authors_string : ''),
        url_for(controller: :manifestation, action: :read, id: m.id)
      )
      if periodical_issue
        work_link + ' (' + link_to(periodical_issue.title, collection_path(periodical_issue)) + ')'
      else
        work_link
      end
    end
    worksbuf.join('; ')
  end
end
