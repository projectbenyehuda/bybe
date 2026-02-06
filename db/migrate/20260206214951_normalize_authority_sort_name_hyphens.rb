# frozen_string_literal: true

# Migration to normalize hyphens and dashes to spaces in Authority sort_name field
# Replaces Hebrew maqaf (־), regular hyphen (-), en dash (–), and em dash (—) with spaces
class NormalizeAuthoritySortNameHyphens < ActiveRecord::Migration[8.0]
  def up
    # Update all authorities with sort_name containing any type of hyphen/dash
    Authority.where.not(sort_name: nil).find_each do |authority|
      original_sort_name = authority.sort_name
      normalized_sort_name = original_sort_name.gsub(/[\u05BE\u002D\u2013\u2014]/, ' ')

      if original_sort_name != normalized_sort_name
        authority.update_column(:sort_name, normalized_sort_name)
      end
    end
  end

  def down
    # No-op: We cannot reliably reverse this migration as we don't know
    # which spaces were originally hyphens
    Rails.logger.warn 'Cannot reverse NormalizeAuthoritySortNameHyphens migration'
  end
end
