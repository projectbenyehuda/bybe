# frozen_string_literal: true

# Service to compute intellectual property status based on involved authorities
# The logic is: if ANY authority is copyrighted/protected, the work is copyrighted
# Only if ALL authorities are public_domain, the work is public_domain
class ComputeIntellectualProperty < ApplicationService
  # Compute intellectual property status from a list of authority IDs
  # @param authority_ids [Array<Integer>] array of authority IDs
  # @return [Symbol] intellectual property status (:public_domain, :copyrighted, :by_permission, :orphan, :unknown)
  def call(authority_ids)
    return :unknown if authority_ids.blank?

    authorities = Authority.where(id: authority_ids)
    return :unknown if authorities.empty?

    # Check if all authorities are public_domain
    all_public_domain = authorities.all?(&:intellectual_property_public_domain?)

    if all_public_domain
      :public_domain
    else
      # If any authority has special permission status, preserve that
      # Otherwise default to copyrighted if not all are public domain
      if authorities.any? { |a| a.intellectual_property_permission_for_all? }
        :by_permission
      elsif authorities.any? { |a| a.intellectual_property_orphan? }
        :orphan
      elsif authorities.any? { |a| a.intellectual_property_copyrighted? }
        :copyrighted
      elsif authorities.any? { |a| a.intellectual_property_permission_for_selected? }
        :by_permission
      else
        :unknown
      end
    end
  end
end
