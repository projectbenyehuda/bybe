class CrowdController < ApplicationController
  before_action :require_crowdsourcer, except: [:index] # for now, we don't allow anonymous crowdsourcing, but we can show the list and encourage logging in
  
  LISTKEY_POPULATE_EDITION = 'crowd_populate_edition_assignment' # key for ListItems

  def index
    if current_user.present? && current_user.crowdsourcer?
      @populate_edition_people = current_user.present? ? Person.find(ListItem.where(listkey: LISTKEY_POPULATE_EDITION, user_id: current_user.id).pluck(:item_id)) : []
      @todo = Expression.where(source_edition: nil).count
      @total = Expression.count
    end
  end

  def populate_edition
    @author = params[:id].present? ? Person.find(params[:id]) : assign_populate_edition
    @works = @author.original_works.includes(:expression).where(expressions: {source_edition: nil}).load
    @translations = @author.translations.includes(:expression).where(expressions: {source_edition: nil}).load
    prep_toc
    @toc_html = MultiMarkdown.new(@toc.cached_toc).to_html.force_encoding('UTF-8')
    @toc_html.gsub!(/<a href="(.*?)\/read\/(\d+)">([^<]+)<\/a>/) do |m|
      "<a href=\"#{$1}/read/#{$2}\" id=\"m#{$2}\">#{$3}</a><br />#{source_edition_html($2)}<br />"
    end
    pcount = 0
    @toc_html.gsub!(/<p([^<]+?)<\/p>/) do |m|
      pcount += 1
      "<p><span id=\"p#{pcount}\" #{$1}</span> <button class=\"btn_copy\" data-id=\"p#{pcount}\">#{t(:copy_to_clipboard)}</button></p>"
    end
  end
  def do_populate_edition
    mids = []
    source_editions = {}
    params.select{|key| key =~ /m\d+/}.each do |key, value|
      if value.present?
        mids << key[1..-1]
        source_editions[key[1..-1]] = value
      end
    end
    mm = Manifestation.where(id: mids).includes(:expression).load
    mm.each do |m|
      m.expression.source_edition = source_editions[m.id.to_s]
      m.expression.save
    end
    flash[:notice] = t(:updated_successfully)
    redirect_to crowd_index_path
  end

  protected

  def source_edition_html(mid)
    return '' if mid.nil?
    m = @works.find{|w| w.id == mid} || @translations.find{|w| w.id == mid}
    m = Manifestation.includes(:expression).find(mid) if m.nil?
    return '' if m.nil?
    se = m.expression.source_edition
    if se.present?
      return "<span id=\"#{mid}\">#{se}</span><button class=\"btn_copy\" data-id=\"#{mid}\">#{t(:copy_to_clipboard)}</button>"
    else
      return "<input type=\"checkbox\" class=\"cb_se\" id=\"cb#{mid}\" /><input type=\"text\" class=\"se_input\" name=\"m#{mid}\"/>"
    end
  end

  def assign_populate_edition
    # TODO: switch to gem with_advisory_lock once we upgrade to Rails 6.x to prevent double assignments
    assigned_authors = ListItem.where(listkey: LISTKEY_POPULATE_EDITION).pluck(:item_id)
    ret = nil
    i = 0
    while ret.nil? && i < 50 # avoid infinite loop if not much work
      e = Expression.where(source_edition: nil).order('RAND()').first
      unless e.translators.empty?
        au = e.translators.first
        ret = au unless assigned_authors.include?(au.id) || au.toc.nil?
      else
        au = e.work.authors.first
        ret = au unless assigned_authors.include?(au.id) || au.toc.nil?
      end
      i += 1
    end
    ListItem.create(listkey: LISTKEY_POPULATE_EDITION, item_id: ret.id, user_id: current_user.id)
    return ret
  end
end
