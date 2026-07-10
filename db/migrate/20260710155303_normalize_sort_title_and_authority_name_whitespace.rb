# frozen_string_literal: true

# Strips leading/trailing whitespace from existing Collection/Manifestation sort_title values and
# Authority name values. Leading whitespace in particular corrupts alphabetical sorting (a leading
# space sorts before every letter and digit), pushing records to the top of browse listings such as
# /collections and /authors.
#
# Going forward, the SortedTitle concern normalizes sort_title on every save; this migration cleans up
# the rows that were imported/edited before that normalization existed. update_column/update_all are
# used to skip validations and callbacks (matching NormalizeAuthoritySortNameHyphens). Affected ES
# indexes must be reindexed separately for the change to take effect in browse listings.
class NormalizeSortTitleAndAuthorityNameWhitespace < ActiveRecord::Migration[8.0]
  # Maps each model to the string column whose leading/trailing whitespace is stripped.
  NORMALIZED_COLUMNS = { Collection => :sort_title, Manifestation => :sort_title, Authority => :name }.freeze

  def up
    NORMALIZED_COLUMNS.each do |klass, column|
      klass.where.not(column => nil).pluck(:id, column).each do |id, value|
        normalized = SortedTitle.normalize_whitespace(value)
        klass.where(id: id).update_all(column => normalized) if normalized != value
      end
    end
  end

  def down
    # No-op: whitespace stripping is not reversible and carried no semantic meaning.
    Rails.logger.warn 'Cannot reverse NormalizeSortTitleAndAuthorityNameWhitespace migration'
  end
end
