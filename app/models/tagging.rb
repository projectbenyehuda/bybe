# frozen_string_literal: true

# Maps tags to other system object (Authorities, Manifestations, etc)
class Tagging < ApplicationRecord
  belongs_to :tag, counter_cache: true
  belongs_to :taggable, polymorphic: true # taggable things include Manifestations, People, Anthologies, ...

  belongs_to :suggester, foreign_key: 'suggested_by', class_name: 'User'
  belongs_to :approver, foreign_key: 'approved_by', class_name: 'User', optional: true

  validates :status, presence: true
  validates :taggable_type, inclusion: { in: %w(Anthology Authority Collection Expression Manifestation Work) }

  enum :status, { pending: 0, approved: 1, rejected: 2, semiapproved: 3, escalated: 4 }

  scope :by_suggester, ->(user) { where(suggested_by: user.id) }

  # Update approved_taggings_count counter cache
  after_create_commit :handle_create_counter_cache
  after_update_commit :handle_update_counter_cache
  after_destroy_commit :handle_destroy_counter_cache

  update_index(->(tagging) { tagging.taggable.class.to_s == 'Person' ? 'people' : 'manifestations'}) {taggable} # change in tags should be reflected in search indexes

  def approve!(approver)
    self.approved_by = approver.id
    self.status = 'approved'
    self.save
  end
 
  def reject!(approver)
    self.approved_by = approver.id
    self.status = 'rejected'
    self.save
  end

  def escalate!(escalator)
    self.update(approved_by: escalator.id, status: 'escalated')
  end

  private

  def handle_create_counter_cache
    # When creating a new tagging, increment if it's approved
    return unless tag_id.present? && approved?

    Tag.increment_counter(:approved_taggings_count, tag_id)
  end

  def handle_update_counter_cache
    # When updating, check if status and/or tag changed
    return unless saved_change_to_status? || saved_change_to_tag_id?

    old_approved =
      if saved_change_to_status?
        status_before_last_save == 'approved'
      else
        approved?
      end
    new_approved = approved?

    if saved_change_to_tag_id?
      previous_tag_id, current_tag_id = saved_change_to_tag_id

      # Adjust old tag's counter based on previous approval state
      if previous_tag_id.present? && old_approved
        Tag.decrement_counter(:approved_taggings_count, previous_tag_id)
      end

      # Adjust new tag's counter based on new approval state
      if current_tag_id.present? && new_approved
        Tag.increment_counter(:approved_taggings_count, current_tag_id)
      end
    elsif tag_id.present? && saved_change_to_status?
      # Tag stayed the same; only status changed
      if old_approved && !new_approved
        # Changed from approved to something else - decrement
        Tag.decrement_counter(:approved_taggings_count, tag_id)
      elsif !old_approved && new_approved
        # Changed to approved from something else - increment
        Tag.increment_counter(:approved_taggings_count, tag_id)
      end
    end
  end

  def handle_destroy_counter_cache
    # When destroying a tagging, decrement if it was approved
    return unless tag_id.present? && approved?

    Tag.decrement_counter(:approved_taggings_count, tag_id)
  end
end
