module ApplicationHelper
  include BybeUtils

  def u8(s)
    return s if s.nil?

    s.force_encoding('UTF-8')
  end

  def get_intro(markdown)
    lines = markdown[0..2000].lines[1..-2]
    if lines.empty?
      lines = markdown[0..[5000, markdown.length].min].lines[0..-2]
    end
    lines.join + '...'
  end

  def about_the_author(au)
    ret = I18n.t(:about_the_author)
    return au&.gender == 'female' ? ret + 'ת' : ret
  end

  def to_the_author_page(au)
    return au&.gender == 'female' ? I18n.t(:to_the_authoress_page) : I18n.t(:to_the_author_page)
  end

  def lineclamp(s, max)
    s.length > max ? s[0..max - 3] + '...' : s
  end

  def url_tag(u)
    return '' if u.blank?
    return 'ויקיפדיה' if u =~ %r{https?://he.wikipedia.org}
    return 'לקסיקון' if u =~ %r{https?://library.osu.edu/projects/hebrew-lexicon}
    return 'VIAF' if u =~ %r{https?://viaf.org/viaf/}

    'אחר'
  end

  def safe_options_for_select(container, selected = nil)
    ret = ''
    container.each_pair do |heading, lineno|
      ret += "<option value='#{lineno}' #{'selected=\'selected\'' if selected == heading}>#{heading}</option>"
    end
    return ret.html_safe
  end

  def viaf_json_to_html(json)
    ret = '<ul>'
    json.each do |j|
      ret += "<li>#{j[0]} (VIAF: #{j[1]})\n"
    end
    ret += '</ul>'
  end

  def absolute_url_from_urlpart(u)
    return Rails.configuration.constants['base_dir'] + u
  end

  def textify_external_link_type(linktype)
    return I18n.t(linktype)
  end

  def options_for_shelves
    # TODO: once user system is in place, add user's custom shelves
    return '<option>' + t(:want_to_read) + '</option><option>' + t(:currently_reading) + '</option><option>' + t(:have_read) + '</option>'
  end

  def textify_genre(genre)
    return I18n.t(:unknown) if genre.nil? or genre.empty?

    return I18n.t("genre_values.#{genre}")
  end

  def textify_intellectual_property(value)
    t(value, scope: 'intellectual_property')
  end

  def textify_boolean(bool)
    bool ? t(:yes) : t(:no)
  end

  def textify_nikkud(nik)
    return I18n.t(:unknown) if nik.nil? or nik.empty?

    return I18n.t(nik)
  end

  def favorite_glyph(value)
    return value ? '6' : '5' # per /BY icons font/ben-yehuda/icons-reference.html
  end

  def textify_role(role, gender)
    case role.to_s
    when 'author'
      return gender == 'female' ? t(:author_f) : t(:author)
    when 'translator'
      return gender == 'female' ? t(:translator_f) : t(:translator)
    when 'editor'
      return gender == 'female' ? t(:editor_f) : t(:editor)
    when 'illustrator'
      return gender == 'female' ? t(:illustrator_f) : t(:illustrator)
    when 'photographer'
      return gender == 'female' ? t(:photographer_f) : t(:photographer)
    when 'publisher'
      return t(:mlbhd)
    when 'contributor'
      return gender == 'female' ? t(:contributor_f) : t(:contributor)
    else
      return t(:unknown)
    end
  end

  def textify_htmlfile_status(st)
    return I18n.t(:unknown) if st.nil? or st.empty?

    case st
    when 'Unknown'
      return t(:unknown)
    when 'BadUTF8'
      return t(:bad_enc)
    when 'FileError'
      return t(:file_err)
    when 'Parsed'
      return t(:parsed)
    when 'Accepted'
      return t(:accepted)
    when 'Analyzed'
      return t(:analyzed)
    when 'Published'
      return t(:published)
    when 'Manual'
      return t(:manual)
    when 'Uploaded'
      return t(:uploaded_directly)
    when 'Superseded'
      return t(:superseded)
    else
      return t(:unknown)
    end
  end

  def textify_toc_status(st)
    return I18n.t(:unknown) if st.nil? or st.empty?

    return I18n.t(st)
  end

  def uncached_sitenotice
    @sns = Sitenotice.enabled.where('fromdate <= ? and todate >= ?', Date.today, Date.today)
    return '' if @sns.empty?

    return @sns.pluck(:body).join('<br />')
  end

  def sitenotice
    Rails.cache.fetch('sitenotices', expires_in: 2.hours) do # memoize
      uncached_sitenotice
    end
  end

  def linkify_people(people)
    return '' if people.nil? or people.empty?

    ret = ''
    i = 0
    people.each do |p|
      ret += ', ' if i > 0
      ret += link_to p.name, authors_show_path(id: p.id)
      i += 1
    end
    return ret
  end

  def pub_linkify_people(people)
    return '' if people.nil? or people.empty?

    ret = ''
    i = 0
    people.each do |p|
      ret += ', ' if i > 0
      ret += link_to p.name, authority_path(id: p.id)
      i += 1
    end
    return ret
  end

  def authors_linked_string(m)
    return m.expression.work.authors.map do |x|
             "<a href=\"#{url_for(controller: :authors, action: :toc, id: x.id)}\">#{x.name}</a>"
           end.join(', ')
  end

  def translators_linked_string(m)
    return m.expression.translators.map do |x|
             "<a href=\"#{url_for(controller: :authors, action: :toc, id: x.id)}\">#{x.name}</a>"
           end.join(', ')
  end

  def intellectual_property_glyph(intellectual_property)
    # per /BY icons font/ben-yehuda/icons-reference.html
    case intellectual_property
    when 'public_domain'
      return 'm'
    when 'copyrighted', 'by_permission', 'permission_for_all', 'permission_for_selected'
      return 'x'
    end
  end

  def newsitem_glyph(item)
    # per icons-reference.html
    case
    when item.publication?
      return nil
    when item.youtube?
      return 'W'
    when item.facebook?
      return 's'
    when item.announcement?
      return 'O'
    end
  end

  def anthology_select_options
    ret = [
      [t(:general),
       [[t(:rename_this_anthology), -1], [t(:create_new_anthology), 0]]]
    ]
    anths = []
    current_user.anthologies.each do |a|
      anths << [a.title, a.id]
      @selected_anthology = a.id if @anthology == a
    end
    ret << [t(:anthologies), anths] unless anths.empty?
    return ret
  end

  def update_param(uri, key, value)
    u = URI(uri)
    pp = URI.decode_www_form(u.query || '').to_h
    pp[key] = value
    u.query = URI.encode_www_form(pp.to_a)
    u.to_s
  end

  def taggee_from_taggable(taggable)
    case taggable.class.to_s
    when 'Manifestation'
      t(:this_work)
    when 'Person'
      taggable.gender == 'female' ? t(:this_author_f) : t(:this_author_m)
    else
      t(:this_item)
    end
  end

  def collection_item_string(collection_item)
    return '' if collection_item.nil?
    return collection_item.alt_title if collection_item.alt_title.present?

    s = collection_item.item.try(:title) if collection_item.item.present?
    return s if s.present?

    s = collection_item.item.try(:name) if collection_item.item.present?
    return s if s.present?

    return ''
  end

  def download_url_by_entity(entity)
    return '#' if entity.blank?

    case entity.class.to_s
    when 'Manifestation'
      return "/download/#{entity.id}"
    # when 'Authority'
    #  return download_author_path(entity)
    when 'Collection'
      return collection_download_path(entity.id)
    when 'Anthology'
      return anthology_download_path(entity.id)
    end
  end

  def download_dialog_id(entity)
    return '' if entity.blank?

    case entity.class.to_s
    when 'Manifestation', 'Collection'
      return 'downloadDlg'
    when 'Anthology'
      return 'downloadAnthologyDlg'
    end
  end

  def download_form_id(entity)
    return '' if entity.blank?

    case entity.class.to_s
    when 'Manifestation', 'Collection'
      return 'download_form'
    when 'Anthology'
      return 'anth_download_form'
    end
  end

  def default_link_by_class(klass, id)
    case klass.to_s
    when 'Manifestation'
      manifestation_path(id)
    when 'Authority'
      authority_path(id)
    when 'Anthology'
      anthology_path(id)
    when 'Work'
      work_show_path(id: id)
    when 'Collection'
      collection_path(id)
    end
  end

  def textify_collection_type(ctype)
    t("collection.type.#{ctype}")
  end

  def textify_collection_up_link(coll)
    "#{t("collection.up_link.#{coll.collection_type}")} - #{coll.title.truncate(35)}"
  end

  def collection_types_options
    Collection.collection_types.reject { |x| x == 'uncollected' }
              .map { |k, _v| [textify_collection_type(k), k] }
  end

  def collection_item_types_options
    Collection.collection_types.reject { |x| x == 'uncollected' }
              .map { |k, _v| [textify_collection_type(k), k] } +
      [
        [t(:work), 'Manifestation'],
        [t(:paratext), 'paratext'],
        [t(:placeholder_item), 'placeholder_item']
      ]
  end

  def role_options
    InvolvedAuthority.roles.keys.map { |role| [textify_authority_role(role), role] }
  end
end
