# frozen_string_literal: true

module Admin
  # CRUD for SavedSelections used in the mass update tool.
  class SavedSelectionsController < ApplicationController
    before_action -> { require_editor('batch_editing') }
    before_action :set_selection, only: %i(show destroy)

    def index
      selections = SavedSelection.visible_to(current_user).includes(:saved_selection_items).order(name: :asc)
      render json: selections.map { |s|
        { id: s.id, name: s.name, shared: s.shared, mine: s.user_id == current_user.id,
          item_count: s.saved_selection_items.size, delete_after: s.delete_after }
      }
    end

    def show
      items = @selection.saved_selection_items.map do |ssi|
        record = ssi.item_type.constantize.find_by(id: ssi.item_id)
        next if record.nil?

        { type: ssi.item_type, id: ssi.item_id, title: record.title }
      end.compact
      render json: { id: @selection.id, name: @selection.name, items: items }
    end

    def create
      selection = SavedSelection.new(
        name: params[:name],
        shared: params[:shared].in?(['true', '1', true]),
        user: current_user
      )

      items_param = params[:items].to_a.map(&:to_unsafe_h)

      ActiveRecord::Base.transaction do
        selection.save!
        items_param.each do |item|
          selection.saved_selection_items.create!(item_type: item['type'], item_id: item['id'].to_i)
        end
      end

      render json: { id: selection.id, name: selection.name, shared: selection.shared }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def destroy
      unless @selection.user_id == current_user.id
        render json: { error: I18n.t('admin.mass_update.errors.not_owner') }, status: :forbidden
        return
      end
      @selection.destroy
      head :no_content
    end

    private

    def set_selection
      @selection = SavedSelection.find_by(id: params[:id])
      return if @selection.present?

      render json: { error: I18n.t('admin.mass_update.errors.record_not_found') }, status: :not_found
    end
  end
end
