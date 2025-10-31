# frozen_string_literal: true

# Service to compute intellectual property status based on involved authorities
# The logic is: if ANY authority is copyrighted/protected, the work is copyrighted
# Only if ALL authorities are public_domain, the work is public_domain
class ComputeIntellectualProperty < ApplicationService
  # Compute intellectual property status from a list of authority IDs
  # @param authority_ids [Array<Integer>] array of authority IDs
  # @return [Symbol] intellectual property status (:public_domain, :copyrighted, :by_permission, :orphan, :unknown)
  #
  # Priority logic (from most to least restrictive):
  # 1. If ALL authorities are public_domain → public_domain (least restrictive)
  # 2. If ANY authority is copyrighted → copyrighted (most restrictive for general use)
  # 3. If ANY authority is orphan → orphan (unknown rights holder, cannot use)
  # 4. If ANY authority has permission → by_permission (can use with permission)
  # 5. Otherwise → unknown (fallback)
  def call(authority_ids)
    return :unknown if authority_ids.blank?

    authorities = Authority.where(id: authority_ids)
    return :unknown if authorities.empty?

    # Check if all authorities are public_domain
    all_public_domain = authorities.all?(&:intellectual_property_public_domain?)
    return :public_domain if all_public_domain

    # Check for most restrictive statuses first
    return :copyrighted if authorities.any?(&:intellectual_property_copyrighted?)
    return :orphan if authorities.any?(&:intellectual_property_orphan?)

    # Check for permission statuses
    if authorities.any?(&:intellectual_property_permission_for_all?) ||
       authorities.any?(&:intellectual_property_permission_for_selected?)
      return :by_permission
    end

    # Fallback for any other case
    :unknown
  end
end
