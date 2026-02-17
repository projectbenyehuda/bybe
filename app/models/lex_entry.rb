# frozen_string_literal: true

# Lexicon Entry (Person, Publication, etc.)
class LexEntry < ApplicationRecord
  include SortedTitle
  include DownloadLink

  has_one :lex_file, dependent: :nullify

  # this can be LexPerson or LexPublication (or...?)
  # TODO: make relation mandatory after all PHP files will be migrated
  belongs_to :lex_item, polymorphic: true, optional: true, dependent: :destroy, inverse_of: :entry

  # Statuses related to migration process
  MIGRATION_STATUSES = %w(raw migrating error verifying verified).freeze

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

  validates :title, :sort_title, :status, presence: true

  # Scopes for verification queue
  scope :needs_verification, -> { where(status: %i(draft verifying error)) }
  scope :in_verification, -> { where(status: :verifying) }
  scope :verified_pending_publish, -> { where(status: :verified) }

  update_index('lex_entries') { self }

  # returns link to page representing this entry in old lexicon system
  # TODO: remove after migration is complete
  def old_lexicon_url
    return nil unless lex_file

    "#{Lexicon::OLD_LEXICON_URL}/#{lex_file.fname}"
  end

  # Returns the attachment selected as the profile image, or nil if none selected
  def profile_image
    return nil unless profile_image_id

    attachments.find_by(id: profile_image_id)
  end

  # Should be called if we want to re-ingest the lex file
  def reset_ingestion!
    return if lex_file.nil? # Should not be called for entries without lex_file

    Chewy.strategy(:atomic) do
      lex_item&.destroy!
      legacy_links.each(&:destroy!)
      attachments.purge
      status_raw!
      lex_file.update!(error_message: nil)
    end
  end

  def self.cached_count
    Rails.cache.fetch('lex_entry_count', expires_in: 24.hours) do
      LexEntry.count
    end
  end

  def self.cached_published_count
    Rails.cache.fetch('lex_entry_published_count', expires_in: 24.hours) do
      LexEntry.where(status: :published).count
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
    %w(title life_years bio description toc az_navbar attachments).each do |key|
      next unless checklist[key]

      total += 1
      verified += 1 if checklist[key]['verified']
    end

    # Count collection items (citations/מראי מקום, links, works)
    %w(citations links works).each do |collection|
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

    if keys.length > 1
      # For nested paths like "works.items.123", navigate to parent and update child
      parent_keys = keys[0..-2]
      last_key = keys.last

      # Navigate to the parent hash, ensuring it exists
      target = checklist
      parent_keys.each do |key|
        target[key] ||= {}
        target = target[key]
      end

      # Set the value on the target
      target[last_key] = { 'verified' => verified, 'notes' => notes }
    else
      # For top-level paths like "title"
      checklist[keys.first] = { 'verified' => verified, 'notes' => notes }
    end

    # Auto-verify parent collections when all items are verified
    auto_verify_collections!(checklist)

    progress['last_updated_at'] = Time.current.iso8601
    update!(verification_progress: progress)
  end

  # Sync works collection in verification checklist when works are added/deleted
  def sync_works_checklist!
    return unless verification_progress.present? && lex_item_type == 'LexPerson'

    progress = verification_progress.deep_dup
    checklist = progress['checklist']
    return unless checklist

    # Get current works from database
    works = lex_item&.works
    current_work_ids = works ? works.pluck(:id).map(&:to_s) : []
    existing_items = checklist.dig('works', 'items') || {}

    # Add new works
    current_work_ids.each do |work_id|
      existing_items[work_id] ||= { 'verified' => false, 'notes' => '' }
    end

    # Remove deleted works
    existing_items.select! { |work_id, _| current_work_ids.include?(work_id) }

    checklist['works']['items'] = existing_items

    # Auto-verify parent collection if all items verified
    auto_verify_collections!(checklist)

    progress['last_updated_at'] = Time.current.iso8601
    update!(verification_progress: progress)
  end

  # Mark all works as verified (called when marking entire works section as verified)
  def mark_all_works_verified!(notes = '')
    return unless verification_progress.present? && lex_item_type == 'LexPerson'

    progress = verification_progress.deep_dup
    checklist = progress['checklist']
    return unless checklist && checklist['works']

    # Get all current work IDs from database
    works = lex_item&.works
    work_ids = works ? works.pluck(:id).map(&:to_s) : []

    # Mark each individual work as verified
    work_ids.each do |work_id|
      checklist['works']['items'] ||= {}
      checklist['works']['items'][work_id] = { 'verified' => true, 'notes' => notes }
    end

    # Mark the works section itself as verified
    checklist['works']['verified'] = true
    checklist['works']['notes'] = notes

    progress['last_updated_at'] = Time.current.iso8601
    update!(verification_progress: progress)
  end

  private

  # Auto-verify collection sections when all items are verified
  def auto_verify_collections!(checklist)
    %w(citations links works).each do |collection|
      next unless checklist[collection]&.dig('items')

      items = checklist[collection]['items']

      # Special handling for works: verify against actual database records
      if collection == 'works' && lex_item_type == 'LexPerson'
        works = lex_item&.works
        actual_work_ids = works ? works.pluck(:id).map(&:to_s) : []

        # Only mark as verified if:
        # 1. We have works in the database
        # 2. All database works have corresponding checklist items
        # 3. All those checklist items are verified
        if actual_work_ids.any?
          all_verified = actual_work_ids.all? do |work_id|
            items[work_id].is_a?(Hash) && items[work_id]['verified'] == true
          end
          checklist[collection]['verified'] = all_verified
        else
          checklist[collection]['verified'] = false
        end
      else
        # For other collections (citations, links), use the simpler check
        checklist[collection]['verified'] =
          items.any? &&
          items.values.all? { |v| v.is_a?(Hash) && v['verified'] == true }
      end
    end
  end

  # Build initial checklist based on item type
  def build_checklist
    checklist = {}

    case lex_item_type
    when 'LexPerson'
      checklist['title'] = { 'verified' => false, 'notes' => '' }
      checklist['life_years'] = { 'verified' => false, 'notes' => '' }
      checklist['bio'] = { 'verified' => false, 'notes' => '' }

      # Works (יצירות)
      work_items = if lex_item&.works&.any?
                     lex_item.works.each_with_object({}) do |work, hash|
                       hash[work.id.to_s] = { 'verified' => false, 'notes' => '' }
                     end
                   else
                     {}
                   end
      checklist['works'] = { 'verified' => false, 'items' => work_items }

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
