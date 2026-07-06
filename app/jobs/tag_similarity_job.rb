# frozen_string_literal: true

# Finds similar tag names and records similarity suggestions.
class TagSimilarityJob < ApplicationJob
  def perform(tag_id)
    begin
      tag = Tag.find(tag_id)
      TagName.pluck(:tag_id, :name).each do |tag_id, name|
        next if tag_id == tag.id
        idx = tag.tag_names.first.similar_to?(name) # returns false if not similar, or the similarity index if similar
        if idx
          ListItem.create!(listkey: 'tag_similarity', item: tag, extra: "#{idx}%:#{tag_id}")
        end
      end
    rescue ActiveRecord::RecordNotFound
      # tag was deleted before this job ran
    end
  end
end
