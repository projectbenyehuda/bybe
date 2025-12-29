# frozen_string_literal: true

# Lexicon Entry (Person, Publication, etc.)
class LexEntry < ApplicationRecord
  has_one :lex_file, dependent: :nullify

  # this can be LexPerson or LexPublication (or...?)
  # TODO: make relation mandatory after all PHP files will be migrated
  belongs_to :lex_item, polymorphic: true, optional: true, dependent: :destroy, inverse_of: :entry

  enum :status, {
    draft: 0,       # entry created but not ready for public access
    published: 1,   # entry approved for public access
    deprecated: 2,  # entry deprecated (maybe superseded by another entry)
    raw: 101,       # migration not done
    migrating: 102, # async migration in progress
    error: 103,     # error during migration
    verifying: 104, # under verification review
    verified: 105   # verification complete, ready for publishing
  }, prefix: true

  has_many_attached :attachments # attachments referenced by link or image on the entry page
  has_many :legacy_links, class_name: 'LexLegacyLink', dependent: :destroy, inverse_of: :lex_entry

  # Returns the attachment selected as the profile image, or nil if none selected
  def profile_image
    return nil unless profile_image_id

    attachments.find { |attachment| attachment.id == profile_image_id }
  end

  validates :title, :sort_title, :status, presence: true

  before_validation :update_sort_title!

  # Scopes for verification queue
  scope :needs_verification, -> { where(status: %i[draft verifying error]) }
  scope :in_verification, -> { where(status: :verifying) }
  scope :verified_pending_publish, -> { where(status: :verified) }

  def self.cached_count
    Rails.cache.fetch('lex_entry_count', expires_in: 24.hours) do
      LexEntry.count
    end
  end

  # Initialize verification progress for this entry
  def start_verification!(user_email)
    update!(
      status: :verifying,
      verification_progress: {
        verified_by: user_email,
        started_at: Time.current.iso8601,
        last_updated_at: Time.current.iso8601,
        checklist: build_checklist,
        overall_notes: '',
        ready_for_publish: false
      }
    )
  end

  # Calculate verification percentage (0-100)
  def verification_percentage
    return 0 if verification_progress.blank? || verification_progress == {}

    checklist = verification_progress['checklist'] || {}
    total = 0
    verified = 0

    # Count top-level items (excluding collections)
    %w[title life_years bio works description toc az_navbar attachments].each do |key|
      next unless checklist[key]

      total += 1
      verified += 1 if checklist[key]['verified']
    end

    # Count collection items (citations/מראי מקום, links)
    %w[citations links].each do |collection|
      next unless checklist[collection]&.dig('items')

      items = checklist[collection]['items']
      total += items.size
      verified += items.count { |_k, v| v['verified'] }
    end

    return 0 if total.zero?

    ((verified.to_f / total) * 100).round
  end

  # Check if all verification items are complete
  def verification_complete?
    verification_percentage == 100
  end

  # Mark entry as verified (only if verification is complete)
  def mark_verified!
    raise 'Verification not complete' unless verification_complete?

    update!(
      status: :verified,
      verification_progress: verification_progress.merge(
        'ready_for_publish' => true,
        'completed_at' => Time.current.iso8601
      )
    )
  end

  # Update a specific checklist item
  def update_checklist_item(path, verified, notes = '')
    progress = verification_progress.deep_dup
    checklist = progress['checklist']

    # Navigate to nested key and update
    keys = path.split('.')
    target = keys.length > 1 ? (checklist.dig(*keys[0..-2]) || checklist) : checklist
    target[keys.last] = { 'verified' => verified, 'notes' => notes }

    progress['last_updated_at'] = Time.current.iso8601
    update!(verification_progress: progress)
  end

  private

  # Build initial checklist based on item type
  def build_checklist
    checklist = {}

    case lex_item_type
    when 'LexPerson'
      checklist['title'] = { 'verified' => false, 'notes' => '' }
      checklist['life_years'] = { 'verified' => false, 'notes' => '' }
      checklist['bio'] = { 'verified' => false, 'notes' => '' }
      checklist['works'] = { 'verified' => false, 'notes' => '' }

      # Citations (מראי מקום)
      citation_items = if lex_item&.citations&.any?
                         lex_item.citations.each_with_object({}) do |cit, hash|
                           hash[cit.id.to_s] = { 'verified' => false, 'notes' => '' }
                         end
                       else
                         {}
                       end
      checklist['citations'] = { 'verified' => false, 'items' => citation_items }

    when 'LexPublication'
      checklist['title'] = { 'verified' => false, 'notes' => '' }
      checklist['description'] = { 'verified' => false, 'notes' => '' }
      checklist['toc'] = { 'verified' => false, 'notes' => '' }
      checklist['az_navbar'] = { 'verified' => false, 'notes' => '' }
    end

    # Links (common to both)
    link_items = if lex_item&.links&.any?
                   lex_item.links.each_with_object({}) do |link, hash|
                     hash[link.id.to_s] = { 'verified' => false, 'notes' => '' }
                   end
                 else
                   {}
                 end
    checklist['links'] = { 'verified' => false, 'items' => link_items }

    # Attachments
    checklist['attachments'] = { 'verified' => false, 'notes' => '' }

    checklist
  end
end
