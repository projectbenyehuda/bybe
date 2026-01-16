require 'json' # for VIAF AutoSuggest
# require 'rdf'
# require 'rdf/vocab'
require 'hebrew'
require 'htmlentities'
require 'gepub'
require 'rmagick'

include ActionView::Helpers::SanitizeHelper

LETTERS = %w(א ב ג ד ה ו ז ח ט י כ ל מ נ ס ע פ צ ק ר ש ת).freeze

# temporary constants until I figure out what changed in RDF.rb's RDF::Vocab::SKOS
SKOS_PREFLABEL = 'http://www.w3.org/2004/02/skos/core#prefLabel'
SKOS_ALTLABEL = 'http://www.w3.org/2004/02/skos/core#altLabel'
HEBMONTHS = { 'ניסן' => 1, 'אייר' => 2, 'סיון' => 3, 'סיוון' => 3, 'תמוז' => 4, 'אב' => 5, 'אלול' => 6, 'תשרי' => 7, 'חשון' => 8, 'חשוון' => 8, 'כסלו' => 9, 'טבת' => 10, 'שבט' => 11, 'אדר' => 12 } # handling Adar Bet is a special pain we're knowingly ignoring
GREGMONTHS = { 'ינואר' => 1, 'פברואר' => 2, 'מרץ' => 3, 'מרס' => 3, 'מארס' => 3, 'אפריל' => 4, 'מאי' => 5, 'יוני' => 6,
               'יולי' => 7, 'אוגוסט' => 8, 'אבגוסט' => 8, 'ספטמבר' => 9, 'אוקטובר' => 10, 'נובמבר' => 11, 'דצמבר' => 12 }
HEB_LETTER_VALUE = { 'א' => 1, 'ב' => 2, 'ג' => 3, 'ד' => 4, 'ה' => 5, 'ו' => 6, 'ז' => 7, 'ח' => 8, 'ט' => 9,
                     'י' => 10, 'כ' => 20, 'ך' => 20, 'ל' => 30, 'מ' => 40, 'ם' => 40, 'נ' => 50, 'ן' => 50, 'ס' => 60, 'ע' => 70, 'פ' => 80, 'ף' => 80, 'צ' => 90, 'ץ' => 90, 'ק' => 100, 'ר' => 200, 'ש' => 300, 'ת' => 400 }

SUSPICIOUS_TITLES = ['מבוא', 'פתיחה', 'הקדמה', 'אחרית דבר', 'אפילוג', 'סוף דבר', 'על הספר']

class TitleValidator < ActiveModel::Validator
  def validate(record)
    return false unless record.title.present?

    okay = true
    SUSPICIOUS_TITLES.each do |suspicious_title|
      if record.title.strip == suspicious_title
        okay = false
        break
      end
    end
    record.errors.add(:title, I18n.t(:title_not_informative)) unless okay
    if record.title =~ /[^\.]\.\s*$/ # old-fashioned published put periods at ends of titles. We don't want them.
      okay = false
      record.errors.add(:title, I18n.t(:title_ends_with_period))
    end
    if record.title =~ /^..?\. / # starts with one or two letters/numbers and a period
      okay = false
      record.errors.add(:title, I18n.t(:title_starts_with_ordinals))
    end
    return okay
  end
end

module BybeUtils
  def boilerplate(title)
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="he" lang="he"><head><meta http-equiv="content-type" content="text/html; charset=UTF-8" /><title>' + title + '</title></head><body dir="rtl" style="text-align:right">'
  end

  def textify_authority_role(role)
    I18n.t(role, scope: 'involved_authority.role')
  end

  def textify_authorities_and_roles(ias, full_url = false)
    return '' unless ias.present?

    ret = ''
    InvolvedAuthority::ROLES_PRESENTATION_ORDER.each do |role|
      ras = ias.select { |ia| ia.role == role }
      next if ras.empty?

      i = 0
      ret += I18n.t(role, scope: 'involved_authority.abstract_roles') + ': '
      ras.each do |ra|
        ret += ', ' if i > 0
        url = full_url ? Rails.application.routes.url_helpers.authority_url(ra.authority) : Rails.application.routes.url_helpers.authority_path(ra.authority)
        ret += "<a href=\"#{url}\">#{ra.authority.name}</a>"
        i += 1
      end
      ret += '<br />'
    end

    #    ias.each do |ia|
    #      ret += ', ' if i > 0
    #      ret += ia.authority.name
    #      ret += ' (' + textify_authority_role(ia.role) + ')' unless ia.role == 'author'
    #      i += 1
    #    end
    return ret
  end

  def epub_role_from_ia_role(role)
    # per https://www.loc.gov/marc/relators/relaterm.html
    case role
    when 'author'
      return 'aut'
    when 'translator'
      return 'trl'
    when 'editor'
      return 'edt'
    when 'illustrator'
      return 'ill'
    when 'photographer'
      return 'pht'
    when 'contributor'
      return 'ctb'
    else
      return 'oth'
    end
  end

  def epub_sanitize_html(html)
    coder = HTMLEntities.new
    buf = coder.decode(html) # convert HTML entities back to actual characters.

    return buf.gsub('<br>', '<br />') # W3C epubcheck doesn't like <br> without closing
  end

  def make_epub(identifier, title, involved_authorities, section_titles, section_texts, tmpid, purl)
    book = GEPUB::Book.new
    book.primary_identifier(identifier, 'BookID', 'URL')
    book.language = 'he'
    book.add_title(title, nil, title_type: GEPUB::TITLE_TYPE::MAIN)
    aus = []
    contributors = []
    involved_authorities.each do |ia|
      if ia.role == 'author'
        aus << ia.authority.name
      else
        contributors << [ia.authority.name, epub_role_from_ia_role(ia.role)]
      end
    end
    aus.each { |a| book.add_creator(a) }
    contributors.each { |c, r| book.add_contributor(c, role: r) }

    book.page_progression_direction = 'rtl' # Hebrew! :)

    # TODO: fix this -- Hebrew text is not being displayed at all, for some reason
    # make cover image
    # canvas = Magick::Image.new(1200, 800) { |img| img.background_color = 'white' }
    # gc = Magick::Draw.new
    # gc.gravity = Magick::CenterGravity
    # gc.pointsize(50)
    ## gc.font('David CLM')
    # gc.font('Noto Sans Hebrew')
    # gc.font_weight(Magick::NormalWeight)
    # gc.font_style(Magick::NormalStyle)
    # gc.fill('black')
    # gc.text(0, 0, title.reverse.center(50))
    # gc.draw(canvas)
    # gc.pointsize(30)
    # gc.text(0, 150, 'פרי עמלם של מתנדבי פרויקט בן־יהודה'.reverse.center(50))
    # gc.pointsize(20)
    # gc.text(0, 250, Date.today.to_s + 'מעודכן לתאריך: '.reverse.center(50))
    # gc.draw(canvas)
    # cover_file = Tempfile.new(['tmp_cover_' + tmpid, '.png'], 'tmp/')
    # canvas.write(cover_file.path)
    # book.add_item('cover.png', content: cover_file.path).cover_image # re-enable when fixed

    # add texts
    boilerplate_start = boilerplate(title)
    boilerplate_end = '</body></html>'

    # add front page instead of graphical cover, for now
    authorities_html = textify_authorities_and_roles(involved_authorities, true) # full URLs for epub
    front_page = boilerplate_start + "<h1>#{title}</h1>\n<p/><h2>#{authorities_html}</h2><p/><p/><p/><p/>מעודכן לתאריך: #{Date.today}<p/><p/>#{I18n.t(:from_pby_and_available_at)} #{purl} <p/><h3><a href='https://benyehuda.org/page/volunteer'>(רוצים לעזור?)</a></h3>" + boilerplate_end
    book.ordered do
      book.add_item('0_front.xhtml').add_content(StringIO.new(front_page)).toc_text(title)
      section_titles.each_with_index do |stitle, i|
        book.add_item((i + 1).to_s + '_text.xhtml').add_content(StringIO.new("#{boilerplate(title)}<h1>#{stitle}</h1>\n#{epub_sanitize_html(section_texts[i])}#{boilerplate_end}")).toc_text(stitle)
      end
    end
    # fname = cover_file.path + '.epub'
    fname = "tmp/tmp_epub_#{tmpid}.epub"
    book.generate_epub(fname)
    # cover_file.close
    return fname
  end

  def make_epub_from_collection(collection)
    section_titles = []
    section_texts = []
    collection.flatten_items.each do |ci|
      section_titles << ci.title

      # Build section text with authority information
      section_html = ''

      # Add involved authorities (plain text, no links for EPUB)
      if ci.involved_authorities.present?
        InvolvedAuthority::ROLES_PRESENTATION_ORDER.each do |role|
          ras = ci.involved_authorities.select { |ia| ia.role == role }
          next if ras.empty?

          role_text = I18n.t(role, scope: 'involved_authority.abstract_roles')
          names = ras.map { |ra| ra.authority.name }.join(', ')
          section_html += "<h3>#{role_text}: #{names}</h3>\n"
        end
      end

      # Add the actual content
      section_html += (ci.collection? ? '<p/>' : ci.to_html)

      section_texts << section_html
    end
    make_epub('https://benyehuda.org/collection/' + collection.id.to_s, collection.title,
              collection.authorities, section_titles, section_texts, "coll_#{collection.id}", "#{Rails.application.routes.url_helpers.root_url}#{Rails.application.routes.url_helpers.collection_path(collection)}")
  end

  def make_epub_from_user_anthology(user_anthology, html)
    section_titles = html.scan(%r{<h1.*?>(.*?)</h1}).map { |x| x[0] }
    section_texts = html.split(%r{<h1.*?</h1>})
    section_texts.shift(1) # skip the header
    make_epub('https://benyehuda.org/anthology/' + user_anthology.id.to_s, user_anthology.title, [], section_titles,
              section_texts, "anth_#{user_anthology.id}", "#{Rails.application.routes.url_helpers.root_url}#{Rails.application.routes.url_helpers.anthology_path(user_anthology)}")
  end

  def make_epub_from_single_html(html, entity, _author_string)
    fname = ''
    case entity.class.to_s
    when 'Manifestation'
      section_titles = html.scan(%r{<h2.*?>(.*?)</h2}).map { |x| x[0] }
      if section_titles.count < (entity.expression.translation? ? 3 : 2) # text witout chapters
        [html]
      else
        section_texts = html.split(%r{<h2.*?</h2>})
        offset = entity.expression.translation? ? 2 : 1
        if section_texts.count - section_titles.count == 1
          section_titles.unshift('*') # no title
        end
        section_texts.shift(offset) # skip the header and the author/translator lines
      end
      fname = make_epub('https://benyehuda.org/read/' + entity.id.to_s, entity.title, entity.involved_authorities, [entity.title],
                        [html], entity.id.to_s, "#{Rails.application.routes.url_helpers.root_url}#{Rails.application.routes.url_helpers.manifestation_path(entity)}")
    when 'Anthology'
      fname = make_epub_from_user_anthology(entity, html)
    when 'Collection'
      fname = make_epub_from_collection(entity)
    end
    return fname
  end

  # return a hash like {:total => total_number_of_non_tags_characters, :nikkud => total_number_of_nikkud_characters, :ratio => :nikkud/:total }
  def count_nikkud(text)
    info = { total: 0, nikkud: 0, ratio: nil }
    ignore = false
    text.each_char do |c|
      if c == '<'
        ignore = true
      elsif c == '>'
        ignore = false
        next
      end
      unless ignore or c.match(/\s/) # ignore tags and whitespace
        info[:nikkud] += 1 if text.is_nikkud(c)
        info[:total] += 1
      end
    end
    if text.length < 200 and text.length > 50
      info[:total] -= 35 # rough compensation for text of index and main page links, to mitigate ratio problem for very short texts
    end
    info[:ratio] = info[:nikkud].to_f / info[:total]
    #    puts "DBG: total #{info[:total]} - nikkud #{info[:nikkud]} - ratio #{info[:ratio]}"
    return info
  end

  # new definition of full nikkud: no more than two (or one, if under three words) of the words lack nikkud
  def is_full_nikkud(text)
    a = text.split(/\b/) # split at word boundaries
    b = a.select { |x| x =~ /[^\s,?!.;'`"\-–]/ } # leave only actual words
    count = 0
    b.each { |word| count += 1 if word.any_nikkud? }
    target = b.length < 3 ? 1 : b.length - 2
    return !(count < target)
  end

  def parse_gregorian(str)
    return Date.new(::Regexp.last_match(3).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(1).to_i) if str =~ %r{(\d\d?)[-/\.–](\d\d?)[-/\.–](\d+)} # try to match numeric date

    # perhaps there's a date with spaces and a Gregorian month name in Hebrew
    GREGMONTHS.keys.each do |m|
      next if str.match(/ב?#{m}\s+/).nil?

      month = GREGMONTHS[m]
      pre = ::Regexp.last_match.pre_match
      year = ::Regexp.last_match.post_match.match(/\d+/).to_s.to_i
      day = pre.match(/\d+/) ? ::Regexp.last_match(0).to_i : 15 # mid-month by default
      unless day > 31 || day < 1 # avoid exceptions on weird date strings
        return Date.new(year, month, day)
      end
    end
    # we couldn't identify a month; try to use just the year
    str.match(/\d+/)
    return Date.new(::Regexp.last_match(0).to_i, 7, 1) # mid-year by default
  end

  def parse_hebrew_year(str)
    i = 0
    s = str
    if str[0] == 'ה'
      i += 5000
      s = str[1..-1]
    elsif str[0] == 'ד'
      i += 4000
      s = str[1..-1]
    end
    s.each_char { |c| i += HEB_LETTER_VALUE[c] if HEB_LETTER_VALUE[c] }
    i += 5000 if i < 1000 and i != 0 # assume current Hebrew millennium if no other one is specified
    return i
  end

  def parse_hebrew_day(str)
    s = str.tr("'\"", '') # ignore quotes
    s = s[0..1] if s.length > 2 # ignore prefixes like ב
    s = s[0] unless s.length == 1 || %w(ט י כ ל).include?(s[0]) # only possible first-letters of a two-character hebrew date day
    i = 0
    s.each_char { |c| i += HEB_LETTER_VALUE[c] }
    return i
  end

  def parse_hebrew_date(str)
    HEBMONTHS.keys.each do |m|
      next if str.match(/ב?\S*#{m}\s+/).nil?

      month = HEBMONTHS[m]
      pre = ::Regexp.last_match.pre_match
      rpos = ::Regexp.last_match.pre_match.rindex(' ')
      pre = ::Regexp.last_match.pre_match[0..rpos - 1] unless rpos.nil? # move back to last space (because month may have contained a prefix, like מרחשוון)
      rpos = pre.rindex(' ')
      pre = pre[rpos + 1..-1] unless pre.empty? or rpos.nil?
      year = ::Regexp.last_match.post_match.match(/\S+"\S/).to_s.strip.tr('\"\'', '')
      day = if pre.empty?
              15
            else
              parse_hebrew_day(pre) || 15 # mid-month by default
            end
      hyear = parse_hebrew_year(year)
      return nil if hyear.nil? || hyear == 0

      hd = Hebruby::HebrewDate.new(day, month, hyear)
      return hd.julian_date
    end
    # no month name -- try treating the whole thing as a Hebrew year
    year = str.match(/\S+"\S/)
    return nil if year.nil?

    year = year.to_s
    if year =~ /[-־–]/ # range of years
      year = year.split(/[-־–]/)[0] # take the first year
    end
    year = year.to_s.strip.tr('\"\'[]()', '')
    hyear = parse_hebrew_year(year)
    return nil if hyear.nil? || hyear == 0

    hd = Hebruby::HebrewDate.new(14, 7, hyear) # mid-year by default
    return hd.julian_date
  end

  def normalize_date(str)
    return nil if str.nil? or str.empty?
    # first look for digits
    return parse_gregorian(str) if str.match(/\d+/)
    # parse hebrew date
    return parse_hebrew_date(str) if str.any_hebrew?

    return nil
  end

  # just return a boolean if the buffer is "full" nikkud
  def full_nikkud(text)
    info = count_nikkud(text)
    (info[:total] > 1000 and info[:ratio] > 0.5) || (info[:total] <= 1000 and info[:ratio] > 0.3)
  end

  # retrieve author name for (relative) directory name d, using provided hash known_authors to cache results
  def author_name_from_dir(d, known_authors)
    if known_authors[d].nil?
      thedir = HtmlDir.where(path: d)
      if thedir.nil? or thedir.empty?
        thedir = HtmlDir.new(path: d, author: "__edit__#{d}")
        thedir.save! # to be filled later
      else
        thedir = thedir[0]
      end
      known_authors[d] = thedir.author.force_encoding('utf-8')
    end
    known_authors[d]
  end

  # attempt to match a string against Person records
  def match_person(str)
    matches = Person.where(name: str)
    return matches unless matches.nil?

    lastname = str.split(' ')[-1]
    return Person.where('name LIKE ?', "%#{lastname}%")
  end

  # def guess_authors_viaf(author_string)
  #  # Try VIAF first
  #  viaf = Net::HTTP.new('www.viaf.org')
  #  viaf.start unless viaf.started?
  #  viaf_result = JSON.parse(viaf.get("/viaf/AutoSuggest?query=#{URI.escape(author_string)}").body)
  #  logger.debug("viaf_result: #{viaf_result.to_s}")
  #  logger.debug("viaf_result['result']: #{viaf_result['result'].to_s}")
  #  if viaf_result['result'].nil?
  #    viaf_result = JSON.parse(viaf.get("/viaf/AutoSuggest?query=#{URI.escape(author_string.split(/[, ]/)[0])}").body) # try again with just the first word
  #  end
  #  return nil if viaf_result['result'].nil? # give up
  #  viaf_items = viaf_result['result'].map { |h| [h['term'], h['viafid']] }
  #  logger.info("#{viaf_items.length} results from VIAF for #{author_string}")
  #  viaf_items

  # Try NLI
  # ZOOM::Connection.open('aleph.nli.org.il', 9991) do |conn|
  #  conn.database_name = 'NNL01'
  #  conn.preferred_record_syntax = 'XML'
  #  #conn.preferred_record_syntax = 'USMARC'
  #  rset = conn.search("@attr 1=1003 @attr 2=3 @attr 4=1 @attr 5=100 \"#{author_string}\"")
  #  p rset[0]
  # end
  # end

  def textify_lang(iso)
    return I18n.t(:unknown) if iso.nil? or iso.empty?

    case iso
    when 'he'
      return I18n.t(:hebrew)
    when 'en'
      return I18n.t(:english)
    when 'de'
      return I18n.t(:german)
    when 'ru'
      return I18n.t(:russian)
    when 'es'
      return I18n.t(:spanish)
    when 'yi'
      return I18n.t(:yiddish)
    when 'bg'
      return I18n.t(:bulgarian)
    when 'ka'
      return I18n.t(:georgian)
    when 'arc'
      return I18n.t(:aramaic)
    when 'zh'
      return I18n.t(:chinese)
    when 'pl'
      return I18n.t(:polish)
    when 'ro'
      return I18n.t(:romanian)
    when 'fr'
      return I18n.t(:french)
    when 'ar'
      return I18n.t(:arabic)
    when 'el'
      return I18n.t(:greek)
    when 'la'
      return I18n.t(:latin)
    when 'it'
      return I18n.t(:italian)
    when 'grc'
      return I18n.t(:ancient_greek)
    when 'hu'
      return I18n.t(:hungarian)
    when 'cs'
      return I18n.t(:czech)
    when 'da'
      return I18n.t(:danish)
    when 'no'
      return I18n.t(:norwegian)
    when 'nl'
      return I18n.t(:dutch)
    when 'pt'
      return I18n.t(:portuguese)
    when 'fi'
      return I18n.t(:finnish)
    when 'is'
      return I18n.t(:icelandic)
    when 'fa'
      return I18n.t(:persian)
    when 'sv'
      return I18n.t(:swedish)
    when 'lad'
      return I18n.t(:ladino)
    when 'sa'
      return I18n.t(:sanskrit)
    when 'ta'
      return I18n.t(:tamil)
    when 'sux'
      return I18n.t(:sumerian)
    else
      return I18n.t(:unknown)
    end
  end

  # returns an up-to-maxchars-character snippet and the rest of the buffer
  def snippet(buf, maxchars)
    return [buf, ''] if buf.length < maxchars

    tmp = buf[0..maxchars]
    pos = tmp.rindex(' ')
    ret = tmp[0..pos] # don't break up mid-word
    return [ret, tmp[pos..-1] + ' ' + buf[maxchars..-1]]
  end

  # def raw_viaf_xml_by_viaf_id(viaf_id)
  #  RDF::Graph.load("http://viaf.org/viaf/#{viaf_id}/rdf.xml")
  # end

  # def rdf_collect(graph, uri)
  #  ret = []
  #  query = RDF::Query.new do
  #    pattern [:labels, uri, :datum]
  #  end
  #  query.execute(graph) do |entity|
  #    ret << entity.datum.to_s if entity.datum.to_s.any_hebrew? # we only care about Hebrew labels
  #  end
  #  ret
  # end

  # def viaf_record_by_id(viaf_id)
  #  graph = raw_viaf_xml_by_viaf_id(viaf_id)
  #  query = RDF::Query.new(person: {
  #                           RDF::URI('http://schema.org/birthDate') => :birthDate,
  #                           RDF::URI('http://schema.org/deathDate') => :deathDate
  #                         })
  #  ret = {}
  #  query.execute(graph) do |entity|
  #    ret['birthDate'] = entity.birthDate.to_s unless entity.birthDate.nil?
  #    ret['deathDate'] = entity.deathDate.to_s unless entity.deathDate.nil?
  #  end
  #  ret['labels'] = []
  #  ret['labels'] += rdf_collect(graph, RDF::URI('http://www.w3.org/2004/02/skos/core#prefLabel'))
  #  ret['labels'] += rdf_collect(graph, RDF::URI(SKOS_PREFLABEL))
  #  if ret['labels'].empty? # if there are no Hebrew prefLabels, try the altLabels
  #    ret['labels'] += rdf_collect(graph, RDF::URI(SKOS_ALTLABEL))
  #  end
  #
  #  ret
  # end

  def fix_encoding(buf)
    newbuf = buf.force_encoding('windows-1255')
    ENCODING_SUBSTS.each do |s|
      newbuf.gsub!(s[:from].force_encoding('windows-1255'), s[:to])
    end
    return newbuf
  end

  # def is_blacklisted_ip(ip)
  #  # check posting IP against HTTP:BL
  #  unless Rails.configuration.constants['project_honeypot_api_key'].nil?
  #    listing = ProjectHoneypot.lookup(Rails.configuration.constants['project_honeypot_api_key'], ip)
  #    if listing.comment_spammer? or listing.suspicious? # silently ignore spam submissions
  #      logger.info "SPAM IP identified by HTTP:BL lookup.  Ignoring form submission."
  #      return true
  #    end
  #  end
  #  return false
  # end
  def client_ip
    # logger.debug "client_ip - request.env dump follows\n#{request.env.to_s}"
    request.env['HTTP_X_FORWARDED_FOR'] || request.remote_ip
  end

  def remove_payload(buf)
    m = buf.match(/<!-- begin BY head -->/)
    return buf if m.nil? # though, seriously?

    tmpbuf = ::Regexp.last_match.pre_match
    buf.match(/<!-- end BY head -->/)
    tmpbuf += ::Regexp.last_match.post_match
    tmpbuf.match(/<!-- begin BY body -->/)
    newbuf = ::Regexp.last_match.pre_match
    tmpbuf.match(/<!-- end BY body -->/)
    newbuf += ::Regexp.last_match.post_match
    return newbuf
  end

  def remove_toc_links(buf)
    return buf.gsub(%r{<a\s+?href="index.html">.*?</a>}mi, '').gsub(%r{<a\s+?href="/">.*?</a>}mi, '').gsub(
      %r{<a\s+?href="http://benyehuda.org/"}mi, ''
    )
  end

  def remove_prose_table(buf)
    buf =~ %r{<table.*? width="70%".*?>.*?<td.*?>(.*)</td>.*?</table>}im # if prose table exists, grab its contents
    return buf if ::Regexp.last_match(1).nil?

    return ::Regexp.last_match.pre_match + ::Regexp.last_match(1) + ::Regexp.last_match.post_match
  end

  def html2txt(buf)
    coder = HTMLEntities.new
    return strip_tags(coder.decode(buf)).gsub(/<!\[.*?\]>/, '').tr('“”', '""').tr('‘’', "''").strip
  end

  def author_surname_and_initials(author_string) # TODO: support multiple authors
    parts = author_string.split(' ')
    surname = parts.pop
    initials = ''
    parts.each { |p| initials += p[0] }
    if initials.length == 1
      initials += "'"
    elsif initials.length == 0
      return surname
    else
      initials = initials[0..-2] + '"' + initials[-1]
    end
    return surname + ', ' + initials
  end

  def author_surname_and_firstname(author_string) # TODO: support multiple authors
    parts = author_string.split(' ')
    surname = parts.pop
    return surname + ', ' + parts.join(' ')
  end

  def citation_date(date_str)
    return I18n.t(:no_date) if date_str.nil?
    return ::Regexp.last_match(0) if date_str =~ /\d\d\d+/

    return date_str
  end

  def apa_citation(manifestation)
    return author_surname_and_initials(manifestation.author_string) + '. (' + citation_date(manifestation.expression.date) + '). <strong>' + manifestation.title + '</strong>' + '. [גרסה אלקטרונית]. פרויקט בן־יהודה. נדלה בתאריך ' + Date.today.to_s + ". #{request.original_url}"
  end

  def mla_citation(manifestation)
    return author_surname_and_firstname(manifestation.author_string) + ". \"#{manifestation.title}\". <u>פרויקט בן־יהודה</u>. #{citation_date(manifestation.expression.date)}. #{Date.today}. &lt;#{request.original_url}&gt;"
  end

  def asa_citation(manifestation)
    return author_surname_and_firstname(manifestation.author_string) + '. ' + citation_date(manifestation.expression.date) + ". \"#{manifestation.title}\". <strong>פרויקט בן־יהודה</strong>. אוחזר בתאריך #{Date.today}. (#{request.original_url})"
  end

  def identify_genre_by_heading(text)
    case text
    when /שירה/
      return 'poetry'
    when /פרוזה/
      return 'prose'
    when /מסות/, /מאמרים/
      return 'article'
    when /זכרונות/, /זכרונות ויומנים/
      return 'memoir'
    when /תרגום/, /יצירות מתורגמות/
      return 'translations'
    when /מחזות/, /דרמה/
      return 'drama'
    when /משלים/
      return 'fables'
    when /מכתבים/, /אגרות/
      return 'letters'
    when /עיון/
      return 'reference'
    when /מילונים/, /לקסיקונים/
      return 'lexicon'
    else
      return nil
    end
  end

  def divide_by_genre(buf)
    ret_parts = []
    ret_a = []
    genres = []
    part = ''
    lines = buf.lines
    lines.each do |l|
      if l =~ /^##[^#]/
        genre = identify_genre_by_heading(::Regexp.last_match.post_match)
        unless genre.nil?
          unless part.empty? # if not first genre
            genres << part
            ret_parts << [part, ret_a.join]
            ret_a = []
          end
          part = genre
          ret_a << "<a name='#{genre}_g' id='#{genre}_g' class='g_anch'>&nbsp;</a>\n"
        else
          ret_a << l # deliberately don't add the genre name - provided by UI
        end
      else
        ret_a << l
      end
    end
    ret_parts << [part, ret_a.join] # add last batch
    genres << part
    ret_parts.unshift(genres)
    return ret_parts
  end

  def work_count_by_period(p)
    return Expression.cached_work_count_by_periods[p]
  end

  def get_total_headwords
    return DictionaryEntry.cached_count
  end

  ## hardcoded
  def get_periods
    return %w(ancient medieval enlightenment revival modern)
  end

  def get_genres
    return Work::GENRES # translations and icon-font refer to these keys!
  end

  def right_side_genres # TODO: remove if unused
    return %w(poetry prose drama fables article memoir letters reference) # translations and icon-font refer to these keys!
  end

  ## hardcoded according to graphic design
  def glyph_for_genre(genre)
    case genre
    when 'poetry'
      return 't'
    when 'prose'
      return 'l'
    when 'drama'
      return 'k'
    when 'fables'
      return 'E'
    when 'article'
      return 'a'
    when 'memoir'
      return 'j'
    when 'letters'
      return 'w'
    when 'reference'
      return 'v'
    when 'lexicon'
      return 'f'
    when 'translations'
      return 's'
    end
    return '' # fallback
  end

  def get_langs
    return %w(he en fr de ru yi pl ar el la grc hu cs da no sv nl it pt fa fi
              is es ro arc lad zh ka bg sa ta sux unk)
  end

  def get_genres_by_row(row) # just one row at a time
    return case row
           when 1 then %w(poetry prose drama fables)
           when 2 then %w(article memoir letters reference)
           when 3 then %w(surprise lexicon translations)
           end
  end

  def url_for_record(source, source_id)
    case source.source_type
    when 'aleph', 'primo', 'idea'
      url = source.item_pattern.sub('__ID__', source_id.strip)
    when 'hebrewbooks'
      url = source_id.strip
    when 'nli_api'
      url = source_id.sub('/en/', '/he/')
    when 'googlebooks'
      url = "https://books.google.co.il/books?id=#{source_id.strip}"
    end
    return url
  end

  def is_legacy_url(url)
    return false if url =~ %r{rails/active_storage}

    url = '/' + url if url[0] != '/' # prepend slash if necessary
    h = HtmlFile.find_by_url(url)
    # also treat /{author} or /{author}/ or /{author}/index.html as legacy urls
    if h.nil? && (url =~ %r{/([^/]*)/?(index\.html)?})
      h = HtmlDir.find_by_path(::Regexp.last_match(1))
    end
    return !h.nil?
  end

  def redspan(s)
    return '<span style="color:red; font-size: 250%">' + s + '</span>'
  end

  def highlight_suspicious_markdown(buf)
    buf.gsub('**', redspan('**')).gsub('| ', redspan('| ')).gsub('##', redspan('##'))
  end

  def replace_with_redirect(m_id_to_delete, m_id_to_redirect_to)
    m = Manifestation.find(m_id_to_delete)
    h = m.html_files[0]
    ats = AnthologyText.where(manifestation_id: m_id_to_delete)
    ats.each do |at|
      at.manifestation_id = m_id_to_redirect_to
      at.save!
    rescue StandardError
      at.destroy
    end
    h.manifestations[0].manual_delete
    h.manifestation_ids << m_id_to_redirect_to
    h.save
  end

  def footnotes_noncer(html, nonce) # salt footnote markers and bodies with a nonce, to make them unique in collections/anthologies
    # id of footnote reference in body text and link to footnote body
    ret = html.gsub(/<a href="#fn:(\d+)" id="fnref:(\d+)"/m) do |_fn|
      "<a href=\"#fn:#{nonce}_#{::Regexp.last_match(1)}\" id=\"fnref:#{nonce}_#{::Regexp.last_match(2)}\""
    end
    # link back to footnote reference in body text
    ret.gsub!(/<a href="#fnref:(\d+)"/m) do |_fn|
      "<a href=\"#fnref:#{nonce}_#{::Regexp.last_match(1)}\""
    end
    # id of footnote body anchor
    ret.gsub!(/<li id="fn:(\d+)"/m) do |_fn|
      "<li id=\"fn:#{nonce}_#{::Regexp.last_match(1)}\""
    end
    ret
  end

  def pub_title_for_comparison(s)
    ret = if s['/'].nil?
            s[0..[10, s.length].min]
          else
            s[0..[10, s.index('/') - 1].min]
          end
    return ret.strip
  end

  def clean_up_spaces(buf)
    newbuf = ''
    had_any_content = false
    add_space = false
    buf.each_char do |ch|
      is_space = is_codepoint_space(ch.codepoints[0])
      is_bracket = ['[', ']'].include?(ch)
      next if is_space and !had_any_content # skip leading whitespace

      if is_space
        add_space = true
      else
        if add_space and !is_bracket
          newbuf += ' ' # add a single space
          add_space = false
        end
        had_any_content = true unless is_bracket
        newbuf += ch
      end
    end
    return newbuf
  end

  def uri_escape(uri)
    URI::Parser.new.escape uri
  end

  def is_codepoint_space(cp)
    [9, 10, 11, 12, 13, 32, 133, 160, 5760, 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232,
     8233, 8239, 8287, 12_288].include?(cp)
  end

  def au(id)
    Authority.find(id)
  end

  def m(id)
    Manifestation.find(id)
  end

  def c(id)
    Collection.find(id)
  end

  # Create a KWIC (Key Word In Context) style concordance from labelled texts
  #
  # This function processes multiple texts and creates a concordance showing each token's
  # context across all texts. It properly handles Hebrew acronyms which are marked with
  # a quotation mark (") in the penultimate position.
  #
  # @param labelled_texts [Array<Hash>] Array of text entries, each with :label and :buffer keys
  #   - :label [String] A label identifying the source text
  #   - :buffer [String] The text content, with paragraphs separated by newlines
  #
  # @return [Array<Hash>] Array of token entries sorted alphabetically, each containing:
  #   - :token [String] The token (word)
  #   - :instances [Array<Hash>] Sorted array of occurrences, each with:
  #     - :label [String] Source text label
  #     - :before_context [String] Up to 5 tokens appearing before this token
  #     - :after_context [String] Up to 5 tokens appearing after this token
  #     - :paragraph [Integer] 1-indexed paragraph number in the source buffer
  #
  # @example Basic usage
  #   texts = [
  #     { label: 'text A', buffer: "The quick brown fox.\nThe dog runs." },
  #     { label: 'text B', buffer: 'The brown bear.' }
  #   ]
  #   concordance = kwic_concordance(texts)
  #   # Returns tokens sorted alphabetically, each with their contexts
  #
  # @example Hebrew acronyms
  #   texts = [{ label: 'טקסט', buffer: 'מפא"י היתה מפלגה פוליטית.' }]
  #   concordance = kwic_concordance(texts)
  #   # מפא"י is preserved as a single token with the quotation mark
  #
  # @note Punctuation at word boundaries is removed, but quotation marks inside
  #   Hebrew acronyms (in penultimate position) are preserved.
  def kwic_concordance(labelled_texts)
    token_instances = Hash.new { |h, k| h[k] = [] }

    labelled_texts.each do |text_entry|
      label = text_entry[:label]
      buffer = text_entry[:buffer]

      # Split buffer into paragraphs (lines)
      paragraphs = buffer.split("\n").map(&:strip).reject(&:empty?)

      paragraphs.each_with_index do |paragraph, para_index|
        # Tokenize paragraph, preserving Hebrew acronyms
        tokens = tokenize_with_acronyms(paragraph)

        tokens.each_with_index do |token, token_index|
          # Get context (5 tokens before and 5 tokens after)
          before_tokens = tokens[[0, token_index - 5].max...token_index]
          after_tokens = tokens[(token_index + 1)..[tokens.length - 1, token_index + 5].min]

          instance = {
            label: label,
            before_context: before_tokens.join(' '),
            after_context: after_tokens.join(' '),
            paragraph: para_index + 1 # 1-indexed paragraphs
          }

          token_instances[token] << instance
        end
      end
    end

    # Convert hash to array and sort
    result = token_instances.map do |token, instances|
      {
        token: token,
        instances: instances.sort_by { |i| [i[:label], i[:paragraph]] }
      }
    end

    # Sort by token, then by label and paragraph
    result.sort_by { |entry| entry[:token] }
  end

  private

  # Tokenize text while preserving Hebrew acronyms (with " in penultimate position)
  # and removing punctuation at word boundaries
  #
  # Hebrew acronyms are identified by a quotation mark in the penultimate character position.
  # Examples: מפא"י (Mapai), רמטכ"ל (Ramatkal), צה"ל (Tzahal), חט"ב (Hativah)
  #
  # @param text [String] The text to tokenize
  # @return [Array<String>] Array of tokens with punctuation removed from boundaries
  #
  # @note This method:
  #   - Removes leading/trailing punctuation from words
  #   - Preserves quotation marks in Hebrew acronyms (when in penultimate position)
  #   - Treats all other quotation marks as word boundaries
  #   - Preserves letters and numbers as valid token characters
  def tokenize_with_acronyms(text)
    # This regex matches:
    # 1. Words with Hebrew acronym pattern (letters + " + letter)
    # 2. Regular words (letters and digits)
    # Hebrew acronym pattern: one or more word chars, followed by ", followed by one word char
    tokens = []

    # Split on non-word characters (except quotation marks which we need to check for acronyms)
    # This regex splits on anything that's not a letter, digit, or quotation mark
    # It will treat punctuation like ;:;|/ as word boundaries
    text.split(/[^\p{L}\p{N}\p{Mn}"']+/).each do |word_candidate|
      next if word_candidate.empty?

      # At this point, word_candidate contains only letters, digits, and possibly quotation marks

      # First, strip leading and trailing quotes to see what's inside
      stripped = word_candidate.gsub(/^["']+|["']+$/, '')

      # Check if the stripped content is a Hebrew acronym
      # A valid acronym must:
      # - Have at least 3 characters (e.g., X"Y)
      # - Have " in the penultimate position
      # - Have letters before and after the "
      is_acronym = stripped.length >= 3 &&
                   stripped[-2] == '"' &&
                   stripped[-3] =~ /\p{L}/ &&
                   stripped[-1] =~ /\p{L}/

      if is_acronym
        # It's a Hebrew acronym - use the stripped version (quotes at boundaries removed)
        # Examples: "מפא"י" -> מפא"י, מפא"י -> מפא"י
        tokens << stripped
      elsif stripped != word_candidate
        # Had quotes at boundaries that we stripped - now check what's left
        if stripped.include?('"')
          # Still has double quotes in the middle (not acronym) - split on them
          stripped.split('"').each do |part|
            tokens << part unless part.empty?
          end
        elsif stripped.include?("'") && stripped.count("'") == 1 && stripped.length > 2
          # Single apostrophe in middle - likely a contraction, keep it
          tokens << stripped unless stripped.empty?
        elsif stripped.include?("'")
          # Multiple apostrophes - split on them
          stripped.split("'").each do |part|
            tokens << part unless part.empty?
          end
        else
          # No quotes left after stripping boundaries
          tokens << stripped unless stripped.empty?
        end
      elsif word_candidate.include?('"')
        # Has double quotes but not at boundaries and not acronym - split
        word_candidate.split('"').each do |part|
          tokens << part unless part.empty?
        end
      elsif word_candidate.include?("'") && word_candidate.count("'") > 1
        # Has multiple apostrophes - split on them
        word_candidate.split("'").each do |part|
          tokens << part unless part.empty?
        end
      else
        # Regular word without problematic quotes (may have apostrophe in contraction)
        tokens << word_candidate
      end
    end

    tokens
  end
end
