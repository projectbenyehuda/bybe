# frozen_string_literal: true

# Finds similar tag names and records similarity suggestions.
class TagSimilarityJob < ApplicationJob
  def perform(tag_id)
    tag = Tag.find(tag_id)
    tag_name = tag.tag_names.first
    return if tag_name.nil?

    TagName.pluck(:tag_id, :name).each do |other_tag_id, name|
      next if other_tag_id == tag.id

      idx = tag_name.similar_to?(name) # returns false if not similar, or the similarity index if similar
      if idx
        ListItem.create!(listkey: 'tag_similarity', item: tag, extra: "#{idx}%:#{other_tag_id}")
      end
    end
  rescue ActiveRecord::RecordNotFound
    # tag was deleted before this job ran
  end
end
