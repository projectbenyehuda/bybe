# frozen_string_literal: true

# Merges two Works, keeping the older one and moving all associations from the newer one.
# Returns { success: true, kept_work_id: id } or { success: false, error: '...' }
class MergeWorks < ApplicationService
  COPYABLE_COLUMNS = %w(title form date comment genre orig_lang origlang_title).freeze

  def call(work_a, work_b)
    # keep the older work (lower id = created earlier)
    @older, @newer = [work_a, work_b].minmax_by(&:id)

    validation_error = validate_involved_authorities
    return { success: false, error: validation_error } if validation_error

    ActiveRecord::Base.transaction do
      copy_empty_fields
      move_expressions
      move_aboutnesses
      move_taggings
      @newer.reload
      @newer.destroy!
    end
    { success: true, kept_work_id: @older.id }
  rescue StandardError => e
    Rails.logger.error("MergeWorks failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { success: false, error: e.message }
  end

  private

  # Returns an error string if the two works have different involved authorities, nil otherwise.
  def validate_involved_authorities
    older_set = ia_fingerprint(@older)
    newer_set = ia_fingerprint(@newer)
    return nil if older_set == newer_set

    I18n.t(:expressions_link_ia_mismatch)
  end

  def ia_fingerprint(work)
    work.involved_authorities.map { |ia| [ia.authority_id, ia.role] }.sort
  end

  def copy_empty_fields
    COPYABLE_COLUMNS.each do |col|
      if @older[col].blank? && @newer[col].present?
        @older[col] = @newer[col]
      end
    end
    @older.save!
  end

  def move_expressions
    @newer.expressions.each do |expr|
      expr.update!(work: @older)
    end
  end

  def move_aboutnesses
    @newer.aboutnesses.each do |ab|
      ab.update!(aboutable: @older)
    end
  end

  def move_taggings
    existing_tag_ids = @older.taggings.pluck(:tag_id).to_set
    @newer.taggings.each do |tagging|
      if existing_tag_ids.include?(tagging.tag_id)
        tagging.destroy!
      else
        tagging.update!(taggable: @older)
      end
    end
  end
end
