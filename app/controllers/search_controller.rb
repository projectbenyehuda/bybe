class SearchController < ApplicationController
  include Tracking

  def index
  end

  def results
    begin
      @searchterm = params[:search].nil? ? sanitize_term(params[:q]) : sanitize_term(params[:search])
      
      # Get index_types from params, defaulting to all types on first search
      index_types = params[:index_types] || SiteWideSearch.available_index_types
      
      @search = if params[:search].present?
                  SiteWideSearch.new(@searchterm, index_types: index_types)
                else
                  SiteWideSearch.new(query: @searchterm, index_types: index_types)
                end

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
