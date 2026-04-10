# frozen_string_literal: true

# This concern contains common logic used to organize filtering and pagination
module FilteringAndPaginationConcern
  extend ActiveSupport::Concern

  PAGE_SIZE = 100

  private

  def buckets_to_totals_hash(buckets)
    buckets.to_h { |facethash| [facethash['key'], facethash['doc_count']] }
  end

  def paginate(collection)
    @total = collection.count
    @total_pages = (@total / PAGE_SIZE.to_f).ceil

    # After we've swtiched to search_after logic for paging, page is only used to generate proper offset of item indices
    # in works list (e.g. to start second page from index 101)
    @page = (params[:page] || 1).to_i

    prepare_totals(collection) # This method should be implemented in controllers using this concern

    # checking if non-first page should be loaded
    search_after_id = params[:search_after_id]
    search_after_value = params[:search_after_value]
    if search_after_id.present?
      if search_after_value.blank? && @sort_by != 'alphabetical'
        search_after_value = '0'
      end
      collection = collection.search_after(search_after_value, search_after_id)
    end

    if @reverse
      # Fetching previous page
      records = collection.limit(PAGE_SIZE).to_a
      have_more_items = true # we know that there are more items after fetched page
      records.reverse! # reordering items to display them in proper ordering
    else
      # Fetching next page
      # we're retrieving one extra item to check if we have more items after fetched page
      records = collection.limit(PAGE_SIZE + 1).to_a
      have_more_items = records.size == PAGE_SIZE + 1
      records = records[0..-2] if have_more_items # removing extra item
    end

    sort_column = get_sort_column(@sort_by)
    @search_after_for_next = search_after_for_item(records.last, sort_column, false) if have_more_items && records.last
    @search_after_for_previous = search_after_for_item(records.first, sort_column, true) if @page > 1 && records.first

    records
  end

  def search_after_for_item(item, sort_column, reverse)
    # Checking if nested field like 'person.birth_year' was used for sorting
    # NOTE: for now we only support single level of nesting
    sort_path = sort_column.to_s.split('.')
    sort_value = sort_path.length > 1 ? item.send(sort_path.first)[sort_path.last] : item.send(sort_column)
    {
      value: sort_value,
      id: item.id,
      page: reverse ? @page - 1 : @page + 1,
      reverse: reverse.to_s
    }
  end
end
