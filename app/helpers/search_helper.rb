# frozen_string_literal: true

# View helpers for the site-wide search results page.
module SearchHelper
  # "בתוך: <title> (<year>)" for the collection(s) a search-result text is contained in.
  # Returns nil when the text isn't in any volume or periodical issue.
  def containing_collections_label(collections)
    return nil if collections.blank?

    titles = collections.map do |collection|
      year = collection.pub_year
      # a pub_year of 0 is the sentinel used to sort a collection to the head of a page, not a real year
      year.present? && year.to_s.strip != '0' ? "#{collection.title} (#{year})" : collection.title
    end

    t(:contained_in, titles: titles.join('; '))
  end
end
