# frozen_string_literal: true

# Controller to work with InvolvedAuthority records
class InvolvedAuthoritiesController < ApplicationController
  before_action except: %i(index) do |c|
    c.require_editor('edit_catalog')
  end
  before_action :set_involved_authority, only: :destroy
  before_action :set_item, only: %i(create index)

  # renders list of involved authorities linked to item
  def index
    # for now this method is only called from editing forms (after adding new Involved Authority),
    # so we can always pass edit as true
    render partial: 'list_items', locals: { item: @item, edit: true }
  end

  def create
    ia = @item.involved_authorities.build(params.require(:involved_authority).permit(:authority_id, :role))
    if ia.save
      render plain: 'OK'
    else
      render plain: 'Unprocessable entity', status: :unprocessable_content
    end
  end

  # DELETE /involved_authorities/1 or /involved_authorities/1.json
  def destroy
    manifestations = if @involved_authority.item.is_a? Expression
                       @involved_authority.item.manifestations
                     elsif @involved_authority.item.is_a? Work
                       @involved_authority.item.expressions.map(&:manifestations).flatten
                     end

    manifestations.compact.each(&:recalc_cached_people!) if manifestations.present?

    @the_id = "ia#{@involved_authority.id}"
    @involved_authority.destroy!
  end

  private

  def set_involved_authority
    @involved_authority = InvolvedAuthority.find(params[:id])
  end

  def set_item
    item_type = params.fetch(:item_type)
    unless %w(Work Expression Collection).include?(item_type)
      raise ActionController::BadRequest, "Invalid item_type: #{item_type}"
    end
    item_id = params.fetch(:item_id)
    @item = item_type.constantize.find(item_id)
  end
end
