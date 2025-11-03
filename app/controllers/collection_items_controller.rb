# frozen_string_literal: true

class CollectionItemsController < ApplicationController
  before_action :require_editor
  before_action :set_collection_item, only: %i(show edit update destroy drag_item transplant_item)

  # GET /collection_items/1 or /collection_items/1.json
  def show; end

  # GET /collection_items/new
  def new
    @collection_item = CollectionItem.new
  end

  # GET /collection_items/1/edit
  def edit; end

  # POST /collection_items or /collection_items.json
  # called from _manage_collection_items.html.haml
  def create
    success = true
    @collection_item = CollectionItem.new(collection_item_params)
    if params[:collection_item][:item_id].blank?
      unless params[:collection_item][:item_type] == 'Manifestation' # can't create manifestations from here
        if params[:collection_item][:item_type] == 'paratext'
          @collection_item.markdown = @collection_item.alt_title
          @collection_item.paratext = true
          @collection_item.alt_title = nil
          @collection_item.item_type = nil
        elsif params[:collection_item][:item_type] == 'placeholder_item'
          @collection_item.item_id = nil
          @collection_item.item_type = nil
        else
          c = Collection.create!(title: params[:collection_item][:alt_title],
                                 collection_type: params[:collection_item][:item_type])
          @collection_item.item = c # this overrides the passed item_type which is actually collection_type
          @collection_item.alt_title = nil
        end
      else
        success = false
      end
    elsif params[:collection_item][:item_type] == 'other' # adding an existing collection
      @collection_item.item = Collection.find(params[:collection_item][:item_id])
    end

    @collection_id = params[:collection_item][:collection_id]
    @collection = Collection.find(@collection_id)
    @collection_item.seqno = @collection.collection_items.maximum(:seqno).to_i + 1 unless @collection.nil?
    @colls_traversed = []
    @nonce = params[:nonce]
    success = @collection_item.save if success
    respond_to do |format|
      if success
        format.html do
          redirect_to collection_item_url(@collection_item), notice: t(:created_successfully)
        end
        format.js
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @collection_item.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /collection_items/1 or /collection_items/1.json
  def update
    respond_to do |format|
      if @collection_item.update(collection_item_params)
        @element_id = "##{@nonce}_editable_#{@collection_item.id}"
        @html = MultiMarkdown.new(@collection_item.markdown).to_html if params[:collection_item][:markdown].present?
        @title_id = "##{@nonce}_ci_title_#{@collection_item.id}"
        @title = @collection_item.alt_title
        format.html do
          redirect_to collection_item_url(@collection_item), notice: 'Collection item was successfully updated.'
        end
        format.js
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @collection_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /collection_items/1 or /collection_items/1.json
  def destroy
    @collection = @collection_item.collection
    @deleted_id = @collection_item.id # used in the js response
    @collection_item.destroy
    @nonce = params[:nonce]

    respond_to do |format|
      format.html { redirect_to collection_manage_path(@collection.id), notice: t(:deleted_successfully) }
      format.js
    end
  end

  # POST /collection_items/1/drag_item
  def drag_item
    collection = @collection_item.collection
    # zero-based index of where we want to move this item
    new_index = params.fetch(:new_index).to_i

    Collection.transaction do
      items = collection.collection_items.order(:seqno).to_a
      old_index = items.index(@collection_item)
      item_to_move = items.delete_at(old_index)
      items.insert(new_index, item_to_move)

      items.each_with_index do |ci, index|
        ci.update!(seqno: index + 1) unless ci.seqno == index + 1
      end
    end
    head :ok
  end

  # POST /collection_items/1/transplant_item
  def transplant_item
    dest_coll = Collection.find(params[:dest_coll_id].to_i)
    new_pos = params[:new_pos].to_i

    ActiveRecord::Base.transaction do
      # Calculate the new seqno for the item in the destination collection
      new_seqno = if new_pos <= 1
                    1
                  elsif new_pos > dest_coll.collection_items.size
                    dest_coll.collection_items.maximum(:seqno).to_i + 1
                  else
                    dest_coll.collection_items.order(:seqno)[new_pos - 1].seqno
                  end

      # Make space in the destination collection
      dest_coll.collection_items.where('seqno >= ?', new_seqno).order(:seqno).each do |ci|
        ci.increment!(:seqno)
      end

      # Update the collection_item to belong to the new collection with the new seqno
      @collection_item.update!(collection: dest_coll, seqno: new_seqno)
    end
    head :ok
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_collection_item
    @collection_item = CollectionItem.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def collection_item_params
    if params[:collection_item][:nonce].present?
      @nonce = params[:collection_item][:nonce]
      params[:collection_item].delete(:nonce)
    end
    params.require(:collection_item).permit(:collection_id, :alt_title, :context, :seqno, :item_id, :item_type,
                                            :markdown)
  end
end
