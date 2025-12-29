# frozen_string_literal: true

module Lexicon
  # Controller for migration verification workbench
  class VerificationController < ApplicationController
    before_action :set_entry, except: %i[index]
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
      if params[:type].present?
        @entries = @entries.where(lex_item_type: params[:type])
      end
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
        processed_content = content.gsub(/(<link[^>]*href=["'])(?!http|\/)(.*?\.css["'][^>]*>)/i, '\1/lexicon/\2')
                                   .gsub(/(<script[^>]*src=["'])(?!http|\/)(.*?\.js["'][^>]*>)/i, '\1/lexicon/\2')
                                   .gsub(/(<img[^>]*src=["'])(?!http|\/)(.*?["'][^>]*>)/i, '\1/lexicon/\2')
                                   .gsub(/(<a[^>]*href=["'])(?!http|\/|#)(.*?["'][^>]*>)/i, '\1/lexicon/\2')

        render html: processed_content.html_safe, layout: false
      else
        render html: '<div style="padding: 20px; text-align: center; color: #999;">⚠️ קובץ מקור לא נמצא (Source file not found)</div>'.html_safe, layout: false
      end
    end

    # PATCH /lexicon/verification/:id/update_checklist
    def update_checklist
      path = params[:path] # e.g., "title" or "citations.items.123"
      verified = params[:verified] == 'true' || params[:verified] == true
      notes = params[:notes] || ''

      @entry.update_checklist_item(path, verified, notes)

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

    # PATCH /lexicon/verification/:id/set_profile_image
    def set_profile_image
      attachment_id = params[:attachment_id].to_i

      # Verify the attachment belongs to this entry
      unless @entry.attachments.any? { |a| a.id == attachment_id }
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
      @item = @entry.lex_item

      render partial: "lexicon/verification/edit_#{@section}"
    end

    # PATCH /lexicon/verification/:id/update_section
    def update_section
      section = params[:section]
      mark_verified = params[:mark_verified] == '1' || params[:mark_verified] == true
      notes = params[:notes] || ''

      success = true
      errors = []

      # Update entry title if present
      if params[:entry_title].present?
        unless @entry.update(title: params[:entry_title])
          success = false
          errors += @entry.errors.full_messages
        end
      end

      # Update the item (LexPerson or LexPublication)
      if item_params.present?
        unless @entry.lex_item.update(item_params)
          success = false
          errors += @entry.lex_item.errors.full_messages
        end
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
    end
  end
end
