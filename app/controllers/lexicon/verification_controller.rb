# frozen_string_literal: true

module Lexicon
  # Controller for migration verification workbench
  class VerificationController < ApplicationController
    before_action :set_entry, except: %i(index)
    before_action do |c|
      c.require_editor('edit_lexicon')
    end
    layout 'lexicon_backend'

    # GET /lexicon/verification/queue
    def index
      @entries = LexEntry.needs_verification
                         .includes(:lex_item, :lex_file)
                         .order(updated_at: :desc)
                         .page(params[:page])

      # Filter by status if provided
      @entries = @entries.where(status: params[:status]) if params[:status].present?

      # Filter by type if provided
      return if params[:type].blank?

      @entries = @entries.where(lex_item_type: params[:type])
    end

    # GET /lexicon/verification/:id
    def show
      # Initialize verification if not started
      unless @entry.status_verifying? || @entry.status_verified?
        user_email = current_user&.email || 'anonymous@example.com'
        @entry.start_verification!(user_email)
      end

      @source_content = load_source_php
      @checklist = @entry.verification_progress['checklist']
      @item = @entry.lex_item # LexPerson or LexPublication
    end

    # GET /lexicon/verification/:id/source
    # Serves the raw PHP file content to be rendered in iframe
    def source
      content = load_source_php

      if content.present?
        # Rewrite relative URLs to point to /lexicon/ (legacy PHP server)
        # This preserves the original look while fixing 404s in iframe context
        processed_content = content.gsub(%r{(<link[^>]*href=["'])(?!http|/)(.*?\.css["'][^>]*>)}i, '\1/lexicon/\2')
                                   .gsub(%r{(<script[^>]*src=["'])(?!http|/)(.*?\.js["'][^>]*>)}i, '\1/lexicon/\2')
                                   .gsub(%r{(<img[^>]*src=["'])(?!http|/)(.*?["'][^>]*>)}i, '\1/lexicon/\2')
                                   .gsub(%r{(<a[^>]*href=["'])(?!http|/|#)(.*?["'][^>]*>)}i, '\1/lexicon/\2')

        render html: processed_content.html_safe, layout: false
      else
        not_found_msg = '<div style="padding: 20px; text-align: center; color: #999;">' \
                        '⚠️ קובץ מקור לא נמצא (Source file not found)</div>'
        render html: not_found_msg.html_safe, layout: false
      end
    end

    # PATCH /lexicon/verification/:id/update_checklist
    def update_checklist
      path = params[:path] # e.g., "title" or "citations.items.123"
      verified = ['true', true].include?(params[:verified])
      notes = params[:notes] || ''

      # Special handling: when marking entire works section as verified,
      # also mark all individual works as verified
      if path == 'works' && verified && @entry.lex_item_type == 'LexPerson'
        @entry.mark_all_works_verified!(notes)
      else
        @entry.update_checklist_item(path, verified, notes)
      end

      @entry.reload # Ensure we have the latest data

      render json: {
        success: true,
        percentage: @entry.verification_percentage,
        complete: @entry.verification_complete?
      }
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # PATCH /lexicon/verification/:id/save_progress
    def save_progress
      notes = params[:overall_notes] || ''

      progress = @entry.verification_progress.deep_dup
      progress['overall_notes'] = notes
      progress['last_updated_at'] = Time.current.iso8601

      @entry.update!(verification_progress: progress)

      render json: {
        success: true,
        message: I18n.t('lexicon.verification.messages.progress_saved')
      }
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # PATCH /lexicon/verification/:id/confirm_work_match
    # Confirms an auto-matched publication for a work
    def confirm_work_match
      work_id = params[:work_id].to_i
      publication_id = params[:publication_id].to_i
      collection_id = params[:collection_id].to_i if params[:collection_id].present?

      # Find the work and verify it belongs to this entry's person
      work = @entry.lex_item.works.find(work_id)

      # Validate that publication belongs to the person's authority
      person = @entry.lex_item
      if person.authority.blank?
        render json: { success: false, error: 'Person has no associated authority' },
               status: :unprocessable_entity
        return
      end

      publication = person.authority.publications.find_by(id: publication_id)
      unless publication
        render json: { success: false, error: 'Publication does not belong to authority' },
               status: :unprocessable_entity
        return
      end

      # Validate collection if provided
      if collection_id.present?
        collection = Collection.find_by(id: collection_id, publication_id: publication_id)
        unless collection
          render json: { success: false, error: 'Collection does not belong to publication' },
                 status: :unprocessable_entity
          return
        end
      end

      # Update the work with the confirmed publication and collection
      work.update!(
        publication_id: publication_id,
        collection_id: collection_id
      )

      render json: {
        success: true,
        message: I18n.t('lexicon.verification.messages.work_match_confirmed')
      }
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, error: 'Work not found' }, status: :not_found
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # PATCH /lexicon/verification/:id/set_profile_image
    def set_profile_image
      attachment_id = params[:attachment_id].to_i

      # Verify the attachment belongs to this entry using an efficient query
      unless attachment_id.positive? && @entry.attachments.exists?(id: attachment_id)
        render json: { success: false, error: 'Attachment not found' }, status: :not_found
        return
      end

      @entry.update!(profile_image_id: attachment_id)

      render json: {
        success: true,
        profile_image_id: attachment_id
      }
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    # POST /lexicon/verification/:id/mark_verified
    def mark_verified
      @entry.mark_verified!
      redirect_to lexicon_verification_queue_path,
                  notice: I18n.t('lexicon.verification.messages.entry_verified')
    rescue StandardError => e
      redirect_to lexicon_verification_path(@entry),
                  alert: e.message
    end

    # GET /lexicon/verification/:id/edit_section?section=title
    def edit_section
      @section = params[:section]
      # Reload entry and associations to ensure fresh verification_progress data
      @entry = LexEntry.includes(lex_item: :works).find(@entry.id)
      @item = @entry.lex_item

      # Auto-match works to publications if editing works section and authority exists
      if @section == 'works' && @item.is_a?(LexPerson) && @item.authority.present?
        @work_matches = auto_match_works_to_publications(@item)
      end

      render partial: "lexicon/verification/edit_#{@section}"
    end

    # PATCH /lexicon/verification/:id/update_section
    def update_section
      section = params[:section]
      mark_verified = ['1', true].include?(params[:mark_verified])
      notes = params[:notes] || ''

      success = true
      errors = []

      # Update entry title and english_title if present
      entry_updates = {}
      entry_updates[:title] = params[:entry_title] if params[:entry_title].present?
      # For english_title we check key presence rather than value presence so that
      # submitting an empty string will clear the field instead of being ignored.
      entry_updates[:english_title] = params[:english_title] if params.key?(:english_title)

      if entry_updates.present? && !@entry.update(entry_updates)
        success = false
        errors += @entry.errors.full_messages
      end

      # Update the item (LexPerson or LexPublication)
      if item_params.present? && !@entry.lex_item.update(item_params)
        success = false
        errors += @entry.lex_item.errors.full_messages
      end

      if success
        # Update verification checklist if requested
        if mark_verified
          @entry.update_checklist_item(section, true, notes)

          # For LexPerson, the 'title' section includes life years (birthdate/deathdate)
          # so we should mark both checklist items as verified
          if section == 'title' && @entry.lex_item_type == 'LexPerson'
            @entry.update_checklist_item('life_years', true, notes)
          end
        end

        render json: {
          success: true,
          message: I18n.t('lexicon.verification.messages.section_updated'),
          percentage: @entry.verification_percentage,
          complete: @entry.verification_complete?
        }
      else
        render json: {
          success: false,
          errors: errors
        }, status: :unprocessable_entity
      end
    end

    private

    def set_entry
      @entry = LexEntry.includes(:lex_item, :lex_file).find(params[:id])
    end

    def load_source_php
      return nil unless @entry.lex_file&.full_path

      file_path = @entry.lex_file.full_path
      return nil unless File.exist?(file_path)

      # Cache file content in session to avoid repeated disk reads
      cache_key = "lex_file_content_#{@entry.lex_file.id}"
      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        File.read(file_path)
      end
    rescue StandardError => e
      Rails.logger.error("Failed to load source PHP: #{e.message}")
      nil
    end

    def item_params
      # Permit params based on item type
      # Using require().permit() for consistency with rest of codebase
      # rubocop:disable Rails/StrongParametersExpect
      case @entry.lex_item_type
      when 'LexPerson'
        params.require(:lex_person).permit(
          :birthdate, :deathdate, :bio, :works, :gender, :aliases, :copyrighted, :authority_id
        )
      when 'LexPublication'
        params.require(:lex_publication).permit(
          :description, :toc, :az_navbar
        )
      end
      # rubocop:enable Rails/StrongParametersExpect
    end

    # Auto-match works to publications based on title similarity
    # Returns proposed matches WITHOUT persisting to database
    # Format: { work_id => { publication_id:, publication_title:, collection_id:, collection_title:, similarity: } }
    def auto_match_works_to_publications(person)
      matches = {}
      authority = person.authority
      return matches unless authority

      # Get all publications associated with the authority, with volume (collection) eager loaded
      authority_publications = authority.publications.includes(:volume).to_a
      return matches if authority_publications.empty?

      # Build a map of publication_id => collection for efficient lookup
      publication_collections = {}
      authority_publications.each do |pub|
        publication_collections[pub.id] = pub.volume if pub.volume.present?
      end

      # Get authority name for cleaning publication titles
      authority_name = authority.name

      # Only match works that don't already have a publication
      unmatched_works = person.works.where(publication_id: nil)

      unmatched_works.each do |work|
        best_match = find_best_publication_match(work, authority_publications, authority_name)
        next unless best_match

        publication = best_match[:publication]
        # Get collection from our pre-loaded map (no additional query)
        collection = publication_collections[publication.id]

        matches[work.id] = {
          publication_id: publication.id,
          publication_title: publication.title,
          collection_id: collection&.id,
          collection_title: collection&.title,
          similarity: best_match[:similarity]
        }
      end

      matches
    end

    # Find the best publication match for a work
    # Returns { publication: Publication, similarity: Integer } or nil
    def find_best_publication_match(work, publications, authority_name)
      work_title = work.title.to_s.strip
      return nil if work_title.blank?

      best_match = nil
      best_similarity = 0

      publications.each do |pub|
        pub_title = normalize_publication_title(pub.title, authority_name)
        next if pub_title.blank?

        # Try exact match first
        if work_title == pub_title
          return { publication: pub, similarity: 100 }
        end

        # Try fuzzy match using DamerauLevenshtein
        similarity = calculate_similarity(work_title, pub_title)

        # Only consider matches with 70% or higher similarity
        next unless similarity >= 70

        next unless similarity > best_similarity

        best_similarity = similarity
        best_match = pub
      end

      best_match ? { publication: best_match, similarity: best_similarity } : nil
    end

    # Normalize publication title by removing authority name and slashes
    def normalize_publication_title(title, authority_name)
      return '' if title.blank?

      normalized = title.dup

      # Remove authority name (case-insensitive)
      if authority_name.present?
        normalized = normalized.gsub(/#{Regexp.escape(authority_name)}/i, '')
      end

      # Remove forward slashes
      normalized = normalized.gsub('/', '')

      # Clean up whitespace
      normalized.strip
    end

    # Calculate similarity percentage between two strings using DamerauLevenshtein
    # Caps denominator at 20 to reduce false positives on long names
    def calculate_similarity(str1, str2)
      d = DamerauLevenshtein.distance(str1, str2)
      l = [str1.length, str2.length].max.clamp(0, 20).to_f
      return 0 if l.zero?

      ((1 - (d / l)) * 100).round
    end
  end
end
