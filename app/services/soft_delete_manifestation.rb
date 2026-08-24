# frozen_string_literal: true

# Soft-deletes a Manifestation: marks it :deprecated, records in `soft_redirect` the Manifestation
# future requests should be sent to, and re-associates the things that referred to the soft-deleted
# text -- collection items, anthology texts, taggings, recommendations and external links -- with
# that target.
#
# Returns { success: true } or { success: false, error: '...' }.
#
# Every re-association below queries its table directly rather than going through the Manifestation's
# has_many associations, which may already have been loaded on the object handed to us and would then
# hide rows added since.
class SoftDeleteManifestation < ApplicationService
  def call(manifestation, target)
    error = validate(manifestation, target)
    return { success: false, error: error } if error

    ActiveRecord::Base.transaction do
      move_collection_items(manifestation, target)
      move_anthology_texts(manifestation, target)
      move_taggings(manifestation, target)
      move_recommendations(manifestation, target)
      move_external_links(manifestation, target)
      manifestation.update!(status: :deprecated, soft_redirect_target: target)
    end
    { success: true }
  rescue StandardError => e
    Rails.logger.error("SoftDeleteManifestation failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { success: false, error: e.message }
  end

  private

  def validate(manifestation, target)
    return I18n.t(:manifestation_not_found) if target.nil?
    return I18n.t(:soft_delete_same_manifestation) if target.id == manifestation.id
    return I18n.t(:soft_delete_target_deprecated) if target.deprecated?

    nil
  end

  # A collection that already holds the target would otherwise end up listing it twice, so in that
  # collection the soft-deleted text's item is dropped rather than repointed. The other movers below
  # follow the same rule, except that for anthology texts a duplicate is not merely ugly but
  # impossible: anthology_texts carries a unique index on (anthology_id, manifestation_id).
  def move_collection_items(manifestation, target)
    occupied = CollectionItem.where(item: target).pluck(:collection_id).to_set
    CollectionItem.where(item: manifestation).find_each do |ci|
      occupied.include?(ci.collection_id) ? ci.destroy! : ci.update!(item: target)
    end
  end

  def move_anthology_texts(manifestation, target)
    occupied = AnthologyText.where(manifestation: target).pluck(:anthology_id).to_set
    AnthologyText.where(manifestation: manifestation).find_each do |text|
      occupied.include?(text.anthology_id) ? text.destroy! : text.update!(manifestation: target)
    end
  end

  def move_taggings(manifestation, target)
    occupied = Tagging.where(taggable: target).pluck(:tag_id).to_set
    Tagging.where(taggable: manifestation).find_each do |tagging|
      occupied.include?(tagging.tag_id) ? tagging.destroy! : tagging.update!(taggable: target)
    end
  end

  # One user recommending the same text twice makes no sense, so a user who has already recommended
  # the target keeps that recommendation and loses the one on the soft-deleted text.
  def move_recommendations(manifestation, target)
    occupied = Recommendation.where(manifestation: target).pluck(:user_id).to_set
    Recommendation.where(manifestation: manifestation).find_each do |rec|
      occupied.include?(rec.user_id) ? rec.destroy! : rec.update!(manifestation: target)
    end
  end

  def move_external_links(manifestation, target)
    occupied = ExternalLink.where(linkable: target).pluck(:url).to_set
    ExternalLink.where(linkable: manifestation).find_each do |link|
      occupied.include?(link.url) ? link.destroy! : link.update!(linkable: target)
    end
  end
end
