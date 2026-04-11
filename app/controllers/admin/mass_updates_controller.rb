# frozen_string_literal: true

module Admin
  # Handles the mass update tool: selection of records and batch application of changes.
  class MassUpdatesController < ApplicationController
    before_action -> { require_editor('edit_catalog') }
    layout 'backend'

    def new
      # renders new.html.haml
    end

    def create
      records = params[:records].to_a.map(&:to_unsafe_h)
      changes = params[:changes].to_a.map(&:to_unsafe_h)

      if records.blank?
        render json: { error: I18n.t('admin.mass_update.errors.no_records') }, status: :unprocessable_content
        return
      end

      if changes.blank?
        render json: { error: I18n.t('admin.mass_update.errors.no_changes') }, status: :unprocessable_content
        return
      end

      results = MassUpdateService.new(records, changes).apply

      render json: { results: format_results(results) }
    end

    # AJAX: returns id and title for a single Manifestation or Collection record.
    # Params: type (Manifestation|Collection), id
    # Returns: { id:, title:, type: } or 404
    def record_info
      record = case params[:type]
               when 'Manifestation' then Manifestation.find_by(id: params[:id].to_i)
               when 'Collection'    then Collection.find_by(id: params[:id].to_i)
               end
      if record.nil?
        return render json: { error: I18n.t('admin.mass_update.errors.record_not_found') },
                      status: :not_found
      end

      render json: { id: record.id, title: record.title, type: params[:type] }
    end

    # AJAX: returns flat list of all items (recursively) within a collection.
    # Params: collection_id
    # Returns: { items: [{ type:, id:, title:, depth: }, ...] }
    def collection_contents
      collection = Collection.find_by(id: params[:collection_id])
      if collection.nil?
        return render json: { error: I18n.t('admin.mass_update.errors.record_not_found') },
                      status: :not_found
      end

      items = collect_items(collection, 0)
      render json: { items: items }
    end

    # AJAX: returns manifestations whose Expression or Work an authority is involved in.
    # Params: authority_id
    # Returns: { manifestations: [{ id:, title: }, ...] }
    def authority_manifestations
      authority = Authority.find_by(id: params[:authority_id])
      if authority.nil?
        return render json: { error: I18n.t('admin.mass_update.errors.authority_not_found') },
                      status: :not_found
      end

      manifestations = authority.manifestations.select(:id, :title).order(:title)
      render json: { manifestations: manifestations.map { |m| { id: m.id, title: m.title } } }
    end

    private

    def format_results(results)
      results.map do |(type, id), change_results|
        {
          type: type,
          id: id,
          results: change_results.map { |r| r == :ok ? { ok: true } : { ok: false, error: r } }
        }
      end
    end

    # Recursively collects all items in a collection as a flat list.
    def collect_items(collection, depth)
      items = []
      collection.collection_items.includes(:item).order(:seqno).each do |ci|
        next if ci.item.blank?

        case ci.item
        when Manifestation
          items << { type: 'Manifestation', id: ci.item.id, title: ci.item.title, depth: depth }
        when Collection
          items << { type: 'Collection', id: ci.item.id, title: ci.item.title, depth: depth }
          items.concat(collect_items(ci.item, depth + 1))
        end
      end
      items
    end
  end
end
