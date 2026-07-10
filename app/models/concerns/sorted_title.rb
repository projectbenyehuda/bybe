# frozen_string_literal: true

# Module implementing logic for sort_title values generation
# It assumes model has two columns: `title` and `sort_title`. First one is a human-readable string and second one
# contains title normalized for the purpose of sorting.
# This concern add before_validation hook where we strip redundant whitespaces from title and generate normalized
# sort_title from it if neccessary
module SortedTitle
  extend ActiveSupport::Concern

  # Removes leading and trailing Unicode whitespace, including nbsp and other spaces that
  # sometimes arrive with bibliographic data. Internal whitespace is preserved.
  def self.normalize_whitespace(str)
    return str if str.nil?

    str.gsub(/\A\p{Space}+/, '').gsub(/\p{Space}+\z/, '')
  end

  included do
    before_validation do
      strip_whitespaces_from_title!

      # sort_title is re-generated automatically only in two cases:
      # 1) if sort_titl is empty
      # 2) if title was updated, but sort_title was not
      # If sort_title was updated manually (via UI) it will not be re-generated
      if sort_title.blank? || (title_changed? && !sort_title_changed?)
        update_sort_title!
      end

      # Always normalize incidental leading/trailing whitespace, including on manually-set
      # sort_titles that skip regeneration above. Leading whitespace is especially harmful:
      # a leading space sorts before every letter and digit, pushing records to the top of
      # alphabetical browse listings (see /collections).
      strip_whitespaces_from_sort_title!
    end
  end

  def strip_whitespaces_from_title!
    # strip is insufficient as it doesn't remove nbsps, which are sometimes coming from bibliographic data
    self.title = SortedTitle.normalize_whitespace(title) if title.present?
  end

  def strip_whitespaces_from_sort_title!
    self.sort_title = SortedTitle.normalize_whitespace(sort_title) if sort_title.present?
  end

  def update_sort_title!
    # Removing special symbols (quotes, parenthesis, hyphens, etc.) from sort_title
    self.sort_title = title.strip_nikkud.tr('[]()*"\'', '').tr('-־', ' ').strip

    # If sort title starts with number and dot, e.g. "12. Title" we remove numeric prefix and leave only "Title"
    self.sort_title = ::Regexp.last_match.post_match if sort_title =~ /^\d+\. /

    # If sort_title starts from non-hebrew characters we add a prefix to it to make it appear after all hebrew titles
    unless sort_title.blank? || sort_title[0].any_hebrew? || sort_title.start_with?(/\d/)
      # those four characters are the last letter in the Hebrew alphabet
      self.sort_title = "תתתת_#{sort_title}"
    end
  end
end
