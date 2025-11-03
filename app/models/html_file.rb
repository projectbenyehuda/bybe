# This model implements parsing and rendering down of icky fatty Microsoft-Word-generated HTML files into reasonable MultiMarkDown texts.  It makes no attempt at being general-purpose -- it is designed to mass-convert files from Project Ben-Yehuda (http://benyehuda.org), but it is hoped it would be easily adaptable to other mass-conversion efforts of Word-generated HTML files, with some tweaking of the regexps and the markdown generation. --abartov

# require 'zoom' # Z39.50 queries
require 'rmultimarkdown'
include BybeUtils

ENCODING_SUBSTS = [{ from: "\xCA", to: "\xC9" }, # fix weird invalid chars instead of proper Hebrew xolams
                   { from: "\xFC", to: '&uuml;' }, # fix u-umlaut
                   { from: "\xFB", to: '&ucirc;' },
                   { from: "\xFF".force_encoding('windows-1255'), to: '&yuml;' }] # fix u-circumflex

# TODO: remove the legacy parser
class NokoDoc < Nokogiri::XML::SAX::Document
  def initialize
    @markdown = ''
    @in_title = false
    @title = ''
    @in_footnote = false
    @in_subhead = false
    @subhead_fontsize = 0
    @subhead = ''
    @anything = false
    @spans = [] # a span/style stack
    @links = [] # a links stack
    @footnotes = []
    @footnote = {}
    @post_processing_done = false
  end

  def push_style(style)
    @spans.push(style: style, markdown: '', anything: false)
  end

  def start_element(name, attributes)
    # puts "found a #{name} with attributes: #{attributes}"
    if name == 'title'
      @in_title = true
    elsif name == 'span'
      style_attr = attributes.assoc('style')
      style = { decoration: [] }
      unless style_attr.nil?
        # handle style=
        stylestr = style_attr[1]
        if m = /font-family:([^;\"]+)/i.match(stylestr)
          style[:font] = m[1]
        end
        if m = /font-size:(\d\d)\.0pt/i.match(stylestr)
          style[:size] = m[1] # $1
          if style[:size].to_i > 13 # subheadings in prose are usually 16pt, sometimes 14p; in poetry, always greater than 14pt
            @subhead_fontsize = style[:size].to_i # at end_element, when we know if we're looking at full-nikkud text, we'll determine if it's actually a sub-head
            @in_subhead = true
          end
        end
        if m = /text-decoration:underline/i.match(stylestr)
          style[:decoration].push(:underline)
        end
        if m = /font-weight:bold/i.match(stylestr)
          style[:decoration].push(:bold)
        end
      end
      push_style(style)
    elsif name == 'h2' || name == 'h1'
      @in_subhead = true
    elsif name == 'p'
      if attributes.assoc('class').nil?
        class_attr = ''
      else
        class_attr = attributes.assoc('class')[1]
      end
      @in_subhead = true if %w(aa a1).include? class_attr # one heading style in PBY texts, see doc/guide_to_icky_Word_html.txt
    elsif name == 'b'
      push_style(decoration: [:bold])
    elsif name == 'u'
      push_style(decoration: [:underline])
    elsif name == 'a'
      # filter out the index.html and root links
      href = attributes.assoc('href') ? attributes.assoc('href')[1] : ''
      ignore = false
      footnote = false
      if ['index.html', '/', 'http://benyehuda.org', 'http://www.benyehuda.org', 'http://benyehuda.org/', 'http://www.benyehuda.org/'].include?(href) or href =~ /^[.\/]+$/ # TODO: de-uglify
        ignore = true
      elsif href != ''
        # probably a footnote, but could be anything
        # Word-generated footnote references look like this:
        # <a style='mso-footnote-id:ftn12' href="#_ftn12" name="_ftnref12" title="">
        # (followed by a zillion pointless <span> tags...)
        # Then, the footnote itself looks like this:
        # <a style='mso-footnote-id:ftn12' href="#_ftnref12" name="_ftn12" title="">
        # Likewise, endnote references look like this:
        # <a style='mso-endnote-id:edn3' href="#_edn3" name="_ednref3" title="">
        # and the endnote itself looks like this:
        # <a style='mso-endnote-id:edn3' href="#_ednref3" name="_edn3" title="">
        if href.match /_ftn(\d+)/
          footnote_id = Regexp.last_match(1)
          if !@spans.empty?
            @spans.last[:markdown] += "[^ftn#{footnote_id}]"
          else
            @markdown += "[^ftn#{footnote_id}]" # this is the multimarkdown for a footnote reference
          end
          # nothing useful in the content of the anchor of the footnote
          # reference -- a hyperlink to and from the footnote will be
          # auto-generated when rendering HTML, PDF, etc.
          ignore = true
        elsif href.match /_ftnref(\d+)/
          # the beginning of another footnote body (identified through the
          # hyperlink to the footnote reference) is really our only sign that
          # the previous footnote body ended...
          end_footnote(@footnote)
          # start a new footnote, remembering this till the next footnote beginning
          @footnote = { key: Regexp.last_match(1), body: '', markdown: '' }
          @in_footnote = true
          ignore = true # nothing useful, see in the if block just above
        elsif href.match /_edn(\d+)/
          footnote_id = Regexp.last_match(1)+'א' # the aleph protects against identical numbering in footnotes and endnotes. bah.
          if !@spans.empty?
            @spans.last[:markdown] += "[^ftn#{footnote_id}]"
          else
            @markdown += "[^ftn#{footnote_id}]" # this is the multimarkdown for a footnote reference
          end
          # nothing useful in the content of the anchor of the footnote
          # reference -- a hyperlink to and from the footnote will be
          # auto-generated when rendering HTML, PDF, etc.
          ignore = true
        elsif href.match /_ednref(\d+)/
          end_footnote(@footnote)
          @footnote = { key: Regexp.last_match(1)+'א', body: '', markdown: '' }
          @in_footnote = true
          ignore = true # nothing useful, see in the if block just above
        else
          # TODO: handle (preserve) non-footnote links
          ignore = false # TODO: set this to false and actually handle this...
        end
      elsif attributes.assoc('name') # maybe a named anchor?
        anchor = attributes.assoc('name')[1]
        toadd = "<a name=\"#{anchor}\"></a>[#{I18n.t(:back_to_top)}](#)"
        if !@spans.empty?
          @spans.last[:markdown] += toadd
        else
          @markdown += toadd
        end
        ignore = true # nothing further needs to be done at end_element
      end
      @links.push(href: href, ignore: ignore, markdown: '')
    end
  end

  def characters(s)
    if @links.empty? or @links.last['ignore']
      if (s =~ /\p{Word}/)
        @spans.last[:anything] = true if @spans.count > 0  # TODO: optimize, add unless @spans.last[:anything] maybe
      end
      reformat = s.gsub("\n", ' ')
      if @in_title
        @title += reformat
      elsif @in_subhead
        @subhead += reformat
      elsif @in_footnote # buffer footnote bodies separately
        @footnote[:body] += reformat
      elsif !@spans.empty?
        @spans.last[:markdown] += reformat
      else
        @markdown += reformat
      end
    else
      @links.last[:markdown] += s unless @links.empty?
    end
  end

  def error(e)
    puts "ERROR: #{e}" unless /Tag o:p/.match(e) # ignore useless Office tags
  end

  def end_element(name)
    # puts "end element #{name}"
    if name == 'title'
      @in_title = false
      puts "title found: #{@title}"
      @markdown += "\n# #{@title}\n"
    elsif name == 'span' || name == 'b' || name == 'u'
      span = @spans.pop
      new_markdown = ''
      if span[:anything] # don't emit any formatting for the (numerous) useless spans Word generated
        # TODO: determine formatting
        start_formatting = ''
        end_formatting = ''
        if @in_subhead and full_nikkud(@subhead) and @subhead_fontsize < 16
          @in_subhead = false # special case for poetry, where 14pt is the norm!
          span[:markdown] += "\n#{@subhead}" if @subhead =~ /\p{Word}/
          @subhead = ''
          @subhead_fontsize = 0
        end
        if @in_subhead
          @in_subhead = false
          #debugger
          new_markdown += "\n## "+@subhead if @subhead =~ /\p{Word}/
          @subhead = ''
          @subhead_fontsize = 0
        else
          if span[:style][:decoration].include? :bold
            start_formatting += "**" # MultiMarkdown
            end_formatting += "**"
          end

          span[:markdown].strip! # trim whitespace from both sides, to avoid PRE lines in output
          # poetry, bold, underline, indents, size, footnotes, links
          new_markdown += start_formatting + span[:markdown] + end_formatting+' ' # payload (extra space to handle Word's occasionally breaking lines without a space after bold tags
        end
      else
        new_markdown += span[:markdown] # just copy the content, no formatting change
      end
      add_markup(new_markdown)
    elsif ['br','p','h2', 'h1'].include?(name)
      toadd = "\n\n"
      if @in_subhead and full_nikkud(@subhead) and @subhead_fontsize < 16 and name != 'h2' # h2 should override the font-size hack in poetry
        @in_subhead = false
        toadd += "\n"+@subhead + toadd if @subhead =~ /\p{Word}/
        @subhead = ''
        @subhead_fontsize = 0
      end
      if @in_subhead
        @in_subhead = false
        toadd += "\n## "+@subhead + toadd if @subhead =~ /\p{Word}/
        @subhead = ''
        @subhead_fontsize = 0
      end
      add_markup(toadd)
    elsif name == 'a'
      link = @links.pop
      unless link[:ignore]
        toadd = "[#{link[:markdown]}](#{link[:href]})"
        if @in_footnote # buffer footnote bodies separately
          @footnote[:body] += toadd # emit non-footnote non-index links
        else
          add_markup(toadd) # emit non-footnote non-index links
        end
      end
    end
  end

  def save(fname)
    unless @post_processing_done
      post_process
      @post_processing_done = true
    end
    # File.open("/tmp/markdown.txt", 'wb') {|f| f.write(@markdown) } # tmp debug
    # File.open("/tmp/markdown.html", 'wb') {|f| f.write(MultiMarkdown.new(@markdown).to_html) }
    File.open(fname, 'wb') { |f| f.write(@markdown) } # works on any modern Ruby
  end

  def end_footnote(f)
    unless f == {}
      # generate MultiMarkDown for the footnote body and stash it for later
      f[:markdown] = "\n[^ftn#{f[:key]}]: " + f[:body] + "\n" # make sure the footnote body starts on a newline; the newlines are necessary for footnote parsing by MultiMarkDown
      @footnotes.push f
    end
  end

  def post_process # handle any wrap up
    #debugger
    end_footnote(@footnote) # where footnotes exist at all, the last footnote will be pending
    # emit all accumulated footnotes
    markdown = ''
    @footnotes.each do |f|
      markdown += f[:markdown]
    end
    @markdown += markdown # append the entire footnotes section
    @markdown.gsub!("\r", '') # farewell, DOS! :)
    # remove first line's whitespace
    @markdown.gsub!(/\u00a0/,' ') # convert non-breaking spaces to regular spaces, to later get counted as whitespace when compressing
    lines = @markdown.split "\n\n" # by newline by default
    lines.shift while lines[0] !~ /\p{Word}/ # get rid of leading whitespace lines
    lines[0] = lines[0][1..-1] if lines[0][0] == "\n"
    z = /\n[\s]*/.match lines[0]
    lines[0] = z.pre_match + "\n" + z.post_match
    (1..lines.length-1).each {|i|
      #text_only = Nokogiri::HTML(l).xpath("//text()").remove.to_s
      lines[i].strip!
      uniq_chars = lines[i].gsub(/[\s\u00a0]/,'').chars.uniq
      if uniq_chars == ['*'] or uniq_chars == ["\u2013"] # if the line only contains asterisks, or Unicode En-Dash (U+2013)
        lines[i] = '***' # make it a Markdown horizontal rule
      else
        nikkud = count_nikkud(lines[i])
        if (nikkud[:total] > 2000 and nikkud[:ratio] > 0.6) or (nikkud[:total] <= 2000 and nikkud[:ratio] > 0.3)
          # make full-nikkud lines PRE
          lines[i] = '> '+lines[i] unless lines[i] =~ /\[\^ftn/ # produce a blockquote (PRE would ignore bold and other markup)
        end
      end
    }
    # lines.select! {|line| line =~ /\p{Word}/} # this seemed like a good idea, but actually loses the newlines between stanzas # TODO: revisit?
    new_buffer = lines.join "\n\n"
    new_buffer.gsub!("\n\s*\n\s*\n", "\n\n")
    ['.',',',':',';','?','!'].each {|c|
      new_buffer.gsub!(" #{c}",c) # remove spaces before punctuation
    }
    new_buffer.gsub!('©כל הזכויות', '© כל הזכויות') # fix an artifact of the conversion
    new_buffer = new_buffer.gsub('<strong>','<b>').gsub('</strong>','</b>') # apparently the <strong> tag sometimes (when?) causes character-order reversion in the browser
    new_buffer.gsub!(/> (.*?)\n\s*\n\s*\n/, "> \\1\n\n<br>\n") # add <br> tags for poetry, as a workaround to preserve stanza breaks
    new_buffer.gsub!("\n<br>","<br>  ") # sigh
    /#|\p{Word}/.match new_buffer # first non-whitespace char
    @markdown = $& + $' # skip all initial whitespace
  end

  def add_markup(toadd)
    unless @spans.empty?
      @spans.last[:markdown] += toadd
    else
      @markdown += toadd
    end
  end
end

class TranslationValidator < ActiveModel::Validator
  def validate(record)
    okay = true
    if record.translator_id.present? and record.orig_lang == 'he'
      okay = false
      record.errors.add(:base, I18n.t(:translation_must_have_original_language))
    end
    if record.translator_id.blank? and record.orig_lang != 'he'
      okay = false
      record.errors.add(:base, I18n.t(:translation_must_have_translator))
    end
    return okay
  end
end

class HtmlFile < ApplicationRecord
  include EnsureDocxContentType # fixing docx content-type detection problem, per https://github.com/thoughtbot/paperclip/issues/1713
  has_paper_trail
  has_and_belongs_to_many :manifestations

  # for simplicity, only a single author considered per HtmlFile
  # additional authors can be added on the WEM entities later
  belongs_to :author, class_name: 'Authority', optional: true
  belongs_to :translator, class_name: 'Authority', optional: true

  belongs_to :assignee, class_name: 'User', optional: true
  scope :with_nikkud, -> { where("nikkud IS NOT NULL and nikkud <> 'none'") }
  scope :not_stripped, -> { where('stripped_nikkud IS NULL or stripped_nikkud = 0') }
  # attr_accessible :title, :genre, :markdown, :publisher, :comments, :path, :url, :status, :orig_mtime, :orig_ctime, :person_id, :doc, :translator_id, :orig_lang, :year_published

  has_attached_file :doc, storage: :s3, s3_credentials: 'config/s3.yml', s3_region: 'us-east-1'
#  validates_attachment_content_type :doc, content_type: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document']
  validates_attachment_content_type :doc, content_type: ['application/zip', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
  validates :title, presence: true
  validates :genre, presence: true
  validates :publisher, presence: true

  validates_with TitleValidator, on: :create, unless: :override_validation
  validates_with TranslationValidator, on: :create, unless: :override_validation

  def override_validation
    comments =~ /override/
  end

  # a trivial enum just for this entity.  Roles would be expressed with an ActiveRecord enum in the actual (FRBR) catalog entites (Expression etc.)
  ROLE_AUTHOR = 1
  ROLE_TRANSLATOR = 2

  def analyze
    # Word footnotes magic word 'mso-footnote-id'
    begin
      html = File.open(self.path, "r:UTF-8").read
      self.footnotes = (html =~ /mso-footnote-id/) ? true : false
      # Word images magic word: '<img'
      self.images = (html =~ /<img/) ? true : false
      # Word tables magic word (beyond the basic BY formatting table for prose!):
      buf = html
      html.match /<body[^>]*>(.*)<\/body>/m
      coder = HTMLEntities.new
      buf = coder.decode($1) # convert Unicode entities back to actual letters, important for counting nikkud!
      nikkud_info = count_nikkud(buf)
      self.nikkud = if nikkud_info[:nikkud] == 0
                      'none'
                    elsif nikkud_info[:total] > 2000 && nikkud_info[:ratio] < 0.4
                      'some'
                    elsif nikkud_info[:total] <= 2000 && nikkud_info[:ratio] < 0.2
                      'some'
                    else
                      'full'
                    end
      self.tables = false # unless proven otherwise below
      while buf =~ /<table[^>]*>/ do
        # ignore the Ben-Yehuda standard prose 70% table
        thematch = $~.to_s
        if thematch !~ /<table[^>]*width=\"70%\"[^>]*>/
          self.tables = true
        end
        buf = $' # postmatch
      end
      # debugging # print "Analysis results -- footnotes: #{self.footnotes}, images: #{self.images}, tables: #{self.tables}\n"
      self.status = 'Analyzed' if ['Unknown','FileError', 'BadUTF8'].include? self.status
    rescue
      print "error: #{$!}\n"
      if $!.to_s =~ /conversion/
        print "match!"
        self.status = 'BadUTF8'
      else
        print "no match?! err = #{$!}\n"
        self.status = 'FileError'
      end
    end
    self.save!
  end
  def self.analyze_all # class method
    HtmlFile.where(status: 'Unknown').each(&:analyze)
  end
  def author_dir
    relpath = path.sub(Rails.configuration.constants['base_dir'], '')
    relpath[1..-1].sub(/\/.*/, '')
  end
  # this method is, for now, deliberately only callable manually, via the console
  def manual_fix_encoding
    if self.status == 'BadCP1255'
      raw = IO.binread(self.path)
      ENCODING_SUBSTS.each { |s|
        raw.gsub!(s[:from].force_encoding('windows-1255'), s[:to])
      }
      newfile = path + '.fixed_encoding'
      # IO.binwrite(newfile, raw) # this works only on Ruby 1.9.3+
      File.open(newfile, 'wb') { |f| f.write(raw) } # works on any modern Ruby
      begin
        html = File.open(newfile, 'r:windows-1255:UTF-8').read
        # yay! The file is now valid and converts fine to UTF-8! :)
        print "Success! #{newfile} is valid!  Please replace the live file #{path} with #{newfile} manually, for safety.\nI'll wait for you to verify: type 'y' if you want to do this switcheroo NOW: "
        yes = gets.chomp
        if yes == 'y'
          File.rename(path, "#{path}.bad_encoding")
          File.rename(newfile, path)
        end
        self.status = 'Unknown' # so that this file gets re-analyzed after the manual copy
        self.save!
      rescue
        print "fix_encoding replaced 0xCA with 0xC9 but fixed file #{newfile} is still unreadable!  Error: #{$ERROR_INFO}\n" # debug
      end
    else
      print 'fix_encoding called but status doesn''t indicate BadCP1255... Ignoring.' # debug
    end
  end

  def assign(id)
    if self.assignee_id.blank?
      self.assignee_id = id
      save!
    else
      return false
    end
    return true
  end

  def unassign
    self.assignee_id = nil
    save!
  end

  def parse
    html = File.open(self.path, "r:UTF-8").read
    ndoc = NokoDoc.new
    parser = Nokogiri::HTML::SAX::Parser.new(ndoc)
    parser.parse(remove_payload(html)) # parse without whatever "behead" payload is on the static files
    ndoc.save(self.path+'.markdown')
    self.status = 'Parsed' # TODO: error checking?
    self.save!
  end

  def html_ready?
    File.exist? path + '.html'
  end

  def complete_author_string
    HtmlFile.title_from_file(path)[1]
  end

  def title_string
    HtmlFile.title_from_file(path)[0]
  end

  def self.html_entities_coder
    @html_entities_coder ||= HTMLEntities.new
  end

  def author_string
    relpath = path.sub(Rails.configuration.constants['base_dir'], '')
    authordir = relpath[1..-1].sub(/\/.*/, '')
    author_name_from_dir(authordir, {})
  end

  def filepart
    path[path.rindex('/') + 1..-1]
  end

  def has_splits
    self.markdown =~ /^&&& /
  end

  def split_parts
    any_footnotes = self.markdown =~ /\[\^\d+\]/ ? true : false
    prev_key = nil
    titles_order = []
    ret = {}
    footbuf = ''
    i = 1
    self.markdown.split(/^(&&& .*)/).each do |bit|
      if bit[0..3] == '&&& '
        prev_key = "#{bit[4..-1].strip}_ZZ#{i}" # remember next section's title
        stop = false
        begin
          if prev_key =~ /\[\^\d+\]/ # if the title line has a footnote
            footbuf += $& # store the footnote
            prev_key.sub!($&,'').strip! # and remove it from the title
          else
            stop = true
          end
        end until stop # handle multiple footnotes if they exist.
      else
        ret[prev_key] = footbuf+bit unless prev_key.nil? # buffer the text to be put in the prev_key next iteration
        titles_order << prev_key unless prev_key.nil?
        footbuf = ''
      end
      i += 1
    end
    # great! now we have the different pieces sorted, *but* any footnotes are *only* in the last piece, even if they belong in earlier pieces. So we need to fix that.
    if any_footnotes # hey, easy case is easy
      footnotes_by_key = {}
      ret.keys.map{|k| footnotes_by_key[k] = ret[k].scan(/\[\^\d+\][^:]/).map{|line| line[0..-2]} }
      # now that we know which ones belong where, we can move them over
      titles_order.each do |key|
        next if key == titles_order[-1] # last one needs no handling
        next if footnotes_by_key[key].nil?
        buf = ''
        footnotes_by_key[key].each do |foot|
          ret[titles_order[-1]] =~ /(#{Regexp.quote(foot.strip)}:.*?)\[\^\d+\]/m # grab the entire footnote, right up to the next one, into $1
          unless $1
            # okay, it may *be* the last/only one...
            ret[titles_order[-1]] =~ /(#{Regexp.quote(foot.strip)}:.*)/m # grab the rest of the doc
          end
          next unless $1 # shouldn't happen in DOCX conversion, but with manual markdown, anything is possible
          buf += $1 # and buffer it
          ret[titles_order[-1]].sub!($1,'') # and remove it from the final chunk's footnotes, where it does not belong
        end
        ret[key] += "\n"+buf
      end
    end
    return ret
  end

  def delete_pregen
    begin
      File.delete path + '.html' if html_ready?
    rescue
      nil
    end
  end

  # TODO: move those to be controller actions
  def make_html
    make_html_with_params(path + '.html', false)
  end

  def make_html_with_params(filename, with_wrapper)
    if %w(Parsed Accepted Published).include? status
      markdown = File.open(path + '.markdown', 'r:UTF-8').read # slurp markdown
      # erb = ERB.new
      File.open(filename, 'wb') do|f|
        if with_wrapper
          f.write("<html><head><meta charset='utf-8'><title></title></head><body>" + MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8') + '</body></html>')
        else
          f.write(MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8'))
        end
      end
    end
  end

  def make_pdf
    if %w(Parsed Accepted Published).include? status
      # markdown = File.open(self.path+'.markdown', 'r:UTF-8').read # slurp markdown
      # File.open(self.path+'.latex', 'wb') { |f| f.write("\\documentclass[12pt,twoside]{book}\n\\usepackage[utf8x]{inputenc}\n\\usepackage[english,hebrew]{babel}\n\\usepackage{hebfont}\n\\begin{document}"+MultiMarkdown.new(markdown).to_latex.force_encoding('UTF-8')+"\n\\end{document}") }
      ## TODO: find a way to do this without a system() call?
      # result = `pdflatex -halt-on-error #{self.path+'.latex'}`
      make_html(nil)
      result = `wkhtmltopdf page #{path + '.html ' + path + '.pdf'}`
      # TODO: validate result
    end
  end
  def self.pdf_from_any_html(html_buffer)
    tmpfile = Tempfile.new(['pdf2html__','.html'])
    begin
      tmpfile.write(html_buffer)
      tmpfile.flush
      tmpfilename = tmpfile.path
      result = `wkhtmltopdf --encoding 'UTF-8' --page-width 20cm page #{tmpfilename} #{tmpfilename}.pdf`
    rescue
      return nil
    ensure
      tmpfile.close
    end
    "#{tmpfilename}.pdf"
  end

  def self.new_since(t) # pass a Time
    where(['created_at > ?', t.to_s(:db)])
  end

  def self.of_dir(d) # pass a dir part
    where(['path like ?', "%/#{d}/%"])
  end

  def update_markdown(markdown)
    File.open(path + '.markdown', 'wb') { |f| f.write(markdown) }
  end

  def metadata_ready?
    manifestations.empty? ? false : true # ensure WEM created
  end

  # rubocop:disable Naming/AccessorMethodName
  def set_orig_author(orig_author_id)
    self.translator_id = author_id unless author_id.nil? # assume current person should be the translator
    self.author_id = orig_author_id
  end
  # rubocop:enable Naming/AccessorMethodName

  def set_translator(author_id)
    self.translator_id = author_id
  end

  def publish
    return false unless status == 'Accepted' && metadata_ready? && authority.present?

    self.status = 'Published'
    save!
  end

  # rubocop:disable Naming/MethodName
  # rubocop:disable Style/GuardClause
  def create_WEM_new(author_id, the_title, the_markdown, multiple, pub_status = nil)
    if status == 'Accepted'
      begin
        tt = the_title.strip
        p = Authority.find(author_id) # TODO: use self.author_id instead of argument? (Damir)
        Chewy.strategy(:atomic) do
          ActiveRecord::Base.transaction do
            w = Work.new(
              title: tt,
              orig_lang: orig_lang,
              genre: genre,
              comment: comments,
              primary: true # TODO: un-hardcode primariness in new upload flow
            )

            q = (translator.nil? ? p : translator)
            intellectual_property =
              if p.intellectual_property_copyrighted? || q.intellectual_property_copyrighted?
                :copyrighted
              elsif p.intellectual_property_permission_for_selected? || q.intellectual_property_permission_for_selected?
                :copyrighted # assuming worse case when permission is not applied to current work
              elsif p.intellectual_property_unknown? || q.intellectual_property_unknown?
                :unknown
              elsif p.intellectual_property_permission_for_all? || q.intellectual_property_permission_for_all?
                :by_permission
              elsif p.intellectual_property_public_domain? && q.intellectual_property_public_domain?
                :public_domain
              else
                :unknown
              end

            e = w.expressions.build(
              title: tt,
              language: 'he',
              period: q.person&.period, # what to do if corporate body?
              intellectual_property: intellectual_property,
              source_edition: publisher,
              date: year_published,
              comment: comments
            )
            w.involved_authorities.build(authority: p, role: :author)

            if translator_id.present?
              e.involved_authorities.build(authority: translator, role: :translator)
            end

            # the author of the Expression and Manifestation is the translator, if one exists
            em_author = (translator_id.nil? ? p : translator)

            pub_status = if pub_status.blank?
                           # default to uploading new works in unpublished status when author/translator is unpublished
                           em_author.published? && p.published? ? :published : :unpublished
                         else
                           pub_status.to_i
                         end

            m = e.manifestations.build(
              title: tt,
              responsibility_statement: em_author.name,
              conversion_verified: true,
              medium: I18n.t(:etext),
              publisher: Rails.configuration.constants['our_publisher'],
              publication_place: Rails.configuration.constants['our_place_of_publication'],
              publication_date: Time.zone.today,
              markdown: the_markdown,
              comment: comments,
              status: pub_status
            )
            w.save!

            manifestations << m # this HtmlFile itself should know the manifestation created out of it

            # if called for split parts, we need to keep the status 'Accepted' for the check above.
            # Status will be updated be caller.
            self.status = 'Published' unless multiple

            save!
            m.recalc_cached_people!
            if pub_link.present? && pub_link_text.present?
              m.external_links.create!(linktype: :publisher_site, url: pub_link, description: pub_link_text)
            end
          end
        end
        return true
      rescue
        return I18n.t(:frbrization_error)
      end
    else
      return I18n.t(:must_accept_before_publishing)
    end
  end
  # rubocop:enable Style/GuardClause
  # rubocop:enable Naming/MethodName

  def remove_line_nums!
    lines = File.open(path + '.markdown', 'r:UTF-8').read.split("\n")
    new_lines = []
    lines.each {|l|
      line = l.strip
      if line =~ /\d+$/
        new_lines << $`
      elsif line =~ /^(>\s+)?\d+\s+/
        new_lines << "#{$1}#{$'}"
      else
        new_lines << line
      end
    }
    ret = new_lines.join("\n")
    update_markdown(ret)
    return ret
  end

  # this one might be useful to handle poetry
  def paras_to_lines!
    old_markdown = File.open(path + '.markdown', 'r:UTF-8').read
    old_markdown.gsub!("\n\n", "\n")
    old_markdown.gsub!("\r\n", "\n") # files have DOS line-endings
    old_markdown.gsub!("\n    \n", "\n") # remove empty lines
    old_markdown =~ /\n/
    body = $' # after title
    title = $`
    body.gsub!("\n", "\n    ") # make the lines PRE in Markdown
    body.gsub!("\n        ","\n    ") # but not twice, in case the button is pushed again (this one will undo the previous line) # TODO: make this less lazy code
    body.gsub!("\n        ","\n    ") # but not twice, in case the button is pushed again (this one will actually remove extraneous spaces)
    new_markdown = title + "\n\n    " + body
    update_markdown(new_markdown)
  end

  def self.title_from_html(h)
    begin
	    title = nil
	    h.gsub!("\n",'') # ensure no newlines interfere with the full content of <title>...</title>
	    if /<title>(.*)<\/title>/i.match(h)
	      title = Regexp.last_match(1).strip
	      author = Regexp.last_match(1).strip # return whole thing if we can't do better
	      res = /\//.match(title)
	      if res
		title = res.pre_match.strip
		author = res.post_match.strip
	      end
	      title.sub!(/ - .*/, '') # remove " - toxen inyanim"
	      title.sub!(/ \u2013.*/, '') # ditto, with an em-dash
	    end
	    title = self.html_entities_coder.decode(title)
	    author = self.html_entities_coder.decode(author)
	    return [title, author]
    rescue => e
      puts "can't get title from html #{h}"
      return ['','']
    end
  end
  def self.title_from_file(f)
    #puts "title_from_file: #{f}" # DBG
    html = ''
    begin
      html = File.open(f, "r:UTF-8").read
      z = html.gsub("\n", ' ') # ensure no bad encoding
      #puts "read as UTF8" # DBG
    rescue
      begin
        html = File.open(f, "r:windows-1255:UTF-8").read
        puts "read as UTF8 convering from 1255" # DBG
      rescue
        puts "read as binary, fixing encoding and trying to reread" # DBG
        raw = IO.binread(f).force_encoding('windows-1255')
        raw = fix_encoding(raw)
        tmpfile = Tempfile.new(f.sub(Rails.configuration.constants['base_dir'],'').gsub('/',''))
        begin
          tmpfile.write(raw)
          tmpfilename = tmpfile.path
          html = File.open(tmpfilename, "r:windows-1255:UTF-8").read
          tmpfile.close
          puts "read as UTF8 from 1255 after binary fixing" #DBG
        rescue
          return "BAD_ENCODING!"
        end
      end
    end
    title_from_html(html)
  end
  def split_long_lines
    markdown = File.open(path + '.markdown', 'r:UTF-8').read
    #debugger
    splitted = ''
    markdown.each_line do|l|
      if l.length <= 200
        splitted += l + "\n"
      else
        while l.length > 200
          pos = l[1..200].rindex(' ')
          splitted += l[1..pos] + "\n"
          l = l[pos + 1..-1]
        end
        splitted += l + "\n"
      end
    end
    File.open(path + '.unsplit.markdown', 'w:UTF-8').write(markdown)
    File.open(path + '.markdown', 'w:UTF-8').write(splitted)
  end

  def html_dir
    d = path.sub(Rails.configuration.constants['base_dir'], '')
    d = d[1..d.rindex('/')-1]
    HtmlDir.find_by_path(d)
  end

end
