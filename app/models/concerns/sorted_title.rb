# frozen_string_literal: true

# Module implementing logic for sort_title values generation
# It assumes model has two columns: `title` and `sort_title`. First one is a human-readable string and second one
# contains title normalized for the purpose of sorting.
# This concern add before_validation hook where we strip redundant whitespaces from title and generate normalized
# sort_title from it if neccessary
module SortedTitle
  extend ActiveSupport::Concern

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
    end
  end

  def strip_whitespaces_from_title!
    # strip is insufficient as it doesn't remove nbsps, which are sometimes coming from bibliographic data
    self.title = title.strip.gsub(/\p{Space}*$/, '') if title.present?
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
