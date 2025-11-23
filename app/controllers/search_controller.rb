class SearchController < ApplicationController
  include Tracking

  def index
  end

  def results
    begin
      @searchterm = params[:search].nil? ? sanitize_term(params[:q]) : sanitize_term(params[:search])
      
      # Get index_types from params, session, or default to all types
      if params.key?(:index_types)
        # Form was submitted - user explicitly selected filters (or unchecked all)
        # Filter out blank values and default to all types if nothing selected
        index_types = params[:index_types].compact_blank
        index_types = SiteWideSearch.available_index_types if index_types.empty?
        session[:search_index_types] = index_types
      elsif session[:search_index_types].present?
        # Use previously selected filters from session
        index_types = session[:search_index_types]
      else
        # First search without filters - default to all types
        index_types = SiteWideSearch.available_index_types
      end
      
      @search = SiteWideSearch.new(query: @searchterm, index_types: index_types)

      @results = @search.search.page(params[:page])
      page = (params[:page] || 1).to_i
      @offset = (page - 1) * Kaminari.config.default_per_page
      @total = @results.count

      track_event('search', { term: @searchterm, page: page })
    rescue # Faraday::Error::ConnectionFailed => e
      @total = -1
      @errmsg = $!
    end
  end

  def advanced
  end

  protected

  def sanitize_term(term)
    return term.gsub(/(\S)\"(\S)/,'\1\2').gsub('׳',"'").gsub('״','"')
  end
end
