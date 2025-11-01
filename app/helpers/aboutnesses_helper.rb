module AboutnessesHelper
  def aboutness_html(ab, edit)
    html = ''
    case ab.aboutable_type
    when 'Authority'
      html += link_to(ab.aboutable.try(:name), authority_path(ab.aboutable.id))
      html += " (#{Authority.model_name.human})"
    when 'Work'
      html += link_to(ab.aboutable.try(:title), work_show_path(id: ab.aboutable_id))
      html += ' / '
      austr = ''
      ab.aboutable.authors.each do |au|
        austr += "#{link_to(au.name, authority_path(id: au.id))}; "
      end
      html += austr[0..-3]
      html += ' ('+I18n.t(:work)+')'
    when nil
      unless ab.wikidata_qid.nil?
        html += link_to("#{ab.wikidata_label}", 'https://wikidata.org/wiki/Q'+ab.wikidata_qid.to_s+'?uselang=he')
        html += ' ('+I18n.t(:wikidata_item)+')'
      else
        html = t(:unknown)
      end
    end
    if edit
      html += ' || '
      html += link_to(t(:destroy), aboutnesses_remove_path(id: ab.id, manifestation_id: @m.id), :data => { :confirm => t(:are_you_sure) })
    end
  return html
  end

end
