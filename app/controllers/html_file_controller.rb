require 'pandoc-ruby' # for generic DOCX-to-HTML conversions

class HtmlFileController < ApplicationController
  before_action only: %i(edit update new create destroy list list_for_editor publish frbrize edit_markdown
                         mark_superseded) do |c|
    c.require_editor('edit_catalog')
  end
  # before_action :require_user, :only => [:edit, :update]
  before_action :require_admin,
                only: %i(analyze analyze_all parse unsplit chop1 chop2 chop3 choplast1 choplast2 poetry)

  def analyze
    @text = HtmlFile.find(params[:id])
    @text.analyze
    params['status'] = 'Analyzed'
    params['commit'] = 'Commit'
    list
    render action: :list # help user find the newly-analyzed files
  end

  def new
    @text = HtmlFile.new
    @page_title = t(:new_file_to_convert)
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @text }
    end
  end

  def create
    @text = HtmlFile.new(hf_params)
    if @text.author
      @text.assignee = current_user
      @text.status = 'Uploaded'
      respond_to do |format|
        if @text.save
          format.html { redirect_to url_for(action: :edit_markdown, id: @text.id), notice: t(:updated_successfully) }
          format.json { render json: @text, status: :created, location: @text }
        else
          format.html { render action: 'new' }
          format.json { render json: @text.errors, status: :unprocessable_content }
        end
      end
    else
      flash[:error] = t(:must_set_author)
      respond_to do |format|
        format.html { render action: 'new' }
        format.json { render json: @text.errors, status: :unprocessable_content }
      end
    end
  end

  def edit_markdown
    @text = HtmlFile.find(params[:id])
    @page_title = t(:edit_markdown)
    unless params[:markdown].nil?
      @text.markdown = params[:markdown]
      @text.genre = params[:genre] if params[:genre].present?
      @text.orig_lang = params[:orig_lang] if params[:orig_lang].present?
      @text.comments = params[:comments]
      @text.pub_link = params[:pub_link]
      @text.pub_link_text = params[:pub_link_text]
      unless params[:commit] == t(:preview)
        @text.save
      end
    end

    if @text.markdown.nil? # convert on first show
      unless @text.doc.file? # accept no-attachment HTML "files", and start an empty one
        @text.markdown = t(:empty_markdown_template)
        @text.save
      else
        bin = Faraday.get @text.doc.url # grab the doc/x binary
        tmpfile = Tempfile.new(['docx2mmd__', '.docx'], encoding: 'ascii-8bit')
        tmpfile_pp = Tempfile.new(['docx2mmd__pp_', '.docx'], encoding: 'ascii-8bit')
        begin
          tmpfile.write(bin.body)
          tmpfile.flush
          tmpfilename = tmpfile.path
          # preserve linebreaks to post-process after Pandoc!
          docx = Docx::Document.open(tmpfilename)
          docx.paragraphs.each do |p|
            p.text = '&&STANZA&&' if p.text.empty? # replaced with <br> tags in new_postprocess
          end
          docx.save(tmpfile_pp.path) # save modified version
          mem_limit = Rails.env.development? ? '' : ' -M1200m ' # limit memory use in production; otherwise severe server hangs possible
          markdown = `pandoc +RTS #{mem_limit} -RTS -f docx -t markdown_mmd #{tmpfile_pp.path}`
          unless markdown =~ /pandoc: Heap exhausted/
            @text.markdown = new_postprocess(markdown)
          else
            @text.markdown = t(:docx_too_large)
            flash[:error] = t(:conversion_error)
            redirect_to controller: :admin, action: :index
          end
          @text.save
        rescue StandardError => e
          flash[:error] = t(:conversion_error)
          redirect_to controller: :admin, action: :index
        ensure
          tmpfile.close
        end
      end
    end
    @markdown = @text.markdown
    @html = ''
    @disable_submit = false
    if @text.has_splits
      validator = TitleValidator.new
      @text.split_parts.each_pair do |title, markdown|
        dummy = Work.new(title: title.sub(/_ZZ\d+/, ''))
        if validator.validate(dummy)
          doctored_title = title
        else
          doctored_title = "<span style='color:red'>#{title}</span><br><span style='color:red'>#{dummy.errors.full_messages.join('<br />')}</span>"
          @disable_submit = true
        end
        @html += "<hr style='border-color:#2b0d22;border-width:20px;margin-top:40px'/><h1>#{doctored_title.sub(/_ZZ\d+/,
                                                                                                               '')}</h1>" + MultiMarkdown.new(markdown).to_html.force_encoding('UTF-8')
      end
    else
      @html = MultiMarkdown.new(@markdown.gsub(/^&&& (.*)/, '<hr style="border-color:#2b0d22;border-width:20px;margin-top:40px"/><h1>\1</h1>')).to_html.force_encoding('UTF-8') # TODO: figure out why to_html defaults to ASCII 8-bit
    end
    @html = highlight_suspicious_markdown(@html)
  end

  def edit
    @text = HtmlFile.find(params[:id])
  end

  def update
    @text = HtmlFile.find(params[:id])
    @text.year_published = params[:year_published]
    @text.orig_year_published = params[:orig_year_published]
    @text.orig_lang = params[:orig_lang]
    @text.orig_author = params[:orig_author]
    @text.orig_author_url = params[:orig_author_url]
    @text.genre = params[:genre]
    @text.comments = params[:comments]
    if @text.save
      flash[:notice] = 'הנתונים עודכנו!'
    else
      flash[:error] = 'אירעה שגיאה.  הנתונים לא נשמרו.  סליחה.'
    end
    redirect_to action: :list_for_editor
  end

  def analyze_all
    # TODO: implement, but only with some safety -- this can take a while!
  end

  def list_for_editor
    if params[:path].blank?
      @dirs = HtmlDir.all
    else
      @author = params[:author]
      @texts = HtmlFile.where('path like ?', '%/' + params[:path] + '/%').order('seqno ASC').page(params[:page])
    end
  end

  def list
    # calculate tallies
    @total_texts = HtmlFile.count
    @total_known = HtmlFile.where.not(status: 'Unknown').count
    @total_images = HtmlFile.where(images: true).count
    @total_footnotes = HtmlFile.where(footnotes: true).count
    @total_tables = HtmlFile.where(tables: true).count
    @total_badenc = HtmlFile.where(status: 'BadCP1255').count
    @total_fileerr = HtmlFile.where(status: 'FileError').count
    @total_parsed = HtmlFile.where(status: 'Parsed').count
    @total_uploaded = HtmlFile.where(status: 'Uploaded').count
    @total_accepted = HtmlFile.where(status: 'Accepted').count
    @total_superseded = HtmlFile.where(status: 'Superseded').count
    @total_published = HtmlFile.where(status: 'Published').count
    @total_manual = HtmlFile.where(status: 'Manual').count
    @total_nikkud_full = HtmlFile.where(nikkud: 'full').count
    @total_nikkud_some = HtmlFile.where(nikkud: 'some').count
    @total_assigned = HtmlFile.where("assignee_id is not null and status != 'Published' and status != 'Superseded'").count
    # build query condition
    query = {}
    if params[:commit].present?
      session[:html_q_params] = params.permit(:nikkud, :footnotes, :status, :path, :title) # make prev. params accessible to view
    elsif session[:html_q_params].nil?
      session[:html_q_params] =
        { footnotes: '', nikkud: '', status: params['status'], path: '', title: '' }
    end
    f = session[:html_q_params][:footnotes]
    n = session[:html_q_params][:nikkud]
    s = params[:commit].blank? ? session[:html_q_params][:status] : (params[:status] or session[:html_q_params][:status])
    # p = session[:html_q_params][:path] # retrieve query params whether or not they were POSTed
    title = session[:html_q_params][:title]
    query.merge!(footnotes: f) if f.present?
    query.merge!(nikkud: n) if n.present?
    query.merge!(status: s) if s.present?
    assignee_cond = "assignee_id is null or assignee_id = #{current_user.id}"

    # TODO: figure out how to include filter by path without making the query fugly
    if title.present?
      @texts = HtmlFile.where(assignee_cond).where(query).where('title like ?',
                                                                '%' + title + '%').page(params[:page]).order('updated_at DESC')
    else
      @texts = HtmlFile.where(assignee_cond).where(query).page(params[:page]).order('updated_at DESC')
    end
  end

  def parse
    @text = HtmlFile.find(params[:id])
    if @text.assignee.blank? or @text.assignee = current_user
      @text.assign(current_user.id)
      @text.parse
      redirect_to url_for(action: :render_html, id: @text.id)
    else
      redirect_to url_for(action: :list) # help user find the newly-parsed files
    end
  end

  def mark_manual
    @text = HtmlFile.find(params[:id])
    @text.status = 'Manual'
    @text.assignee_id = nil
    @text.save!
    redirect_to action: :list
  end

  def mark_superseded
    @text = HtmlFile.find(params[:id])
    @text.status = 'Superseded'
    @text.assignee_id = nil
    @text.save!
  end

  def destroy
    h = HtmlFile.find(params[:id])
    unless h.nil?
      h.destroy!
    end
    redirect_to action: :list
  end

  def frbrize
    @text = HtmlFile.find(params[:id])
    if @text.genre.blank?
      flash[:error] = t(:must_set_genre)
      redirect_to action: :render_html, id: @text.id
    else
      unless @text.author.nil?
        oldstatus = @text.status
        @text.status = 'Accepted'
        @text.genre = params['genre'] unless params['genre'].nil?
        @text.save!
        success = false
        au_id = @text.author.id
        if @text.has_splits
          @text.split_parts.each_pair do |title, markdown|
            success = @text.create_WEM_new(au_id, title.sub(/_ZZ\d+/, ''), markdown, true, params[:pub_status])
          end
          @text.status = 'Published' if success == true
          @text.save!
        else
          success = @text.create_WEM_new(au_id, @text.title.sub(/_ZZ\d+/, ''), @text.markdown, false,
                                         params[:pub_status])
        end
        if success == true
          # invalidate cached work list for generated TOCs
          Rails.cache.delete("au_#{au_id}_original_works_by_genre")
          Rails.cache.delete("au_#{au_id}_translations_by_genre")
          Rails.cache.delete("au_#{au_id}_work_count")

          @text.author.publish_if_first!
          flash[:notice] = t(:created_frbr)
        else
          flash[:error] = success
        end
        redirect_to controller: :manifestation, action: :list
      else
        flash[:error] = t(:cannot_create_frbr)
        redirect_to action: :edit_markdown, id: @text.id
      end
    end
  end

  def publish
    @text = HtmlFile.find(params[:id])
    if @text.status == 'Accepted'
      @text.make_html
      if @text.metadata_ready?
        @text.publish
        flash[:notice] = t(:html_file_published)
      else
        flash[:error] = 'Metadata not ready yet!'
      end
    else
      flash[:error] = t(:must_accept_before_publishing)
    end
    redirect_to url_for(action: :list, status: 'Parsed') # help user find the newly-parsed files
  end

  def unsplit
    @text = HtmlFile.find(params[:id])
    @markdown = File.open(@text.path + '.markdown', 'r:UTF-8').read
    @markdown.gsub!('__SPLIT__', '') # remove magic words
    @text.update_markdown(@markdown)
    redirect_to action: :render_html, id: params[:id]
  end

  def render_by_legacy_url
    if params[:format] && params[:format] == 'xml'
      head :bad_request
    else
      the_url = params[:path] + '.html'
      the_url = '/' + the_url if the_url[0] != '/' # prepend slash if necessary
      h = HtmlFile.find_by_url(the_url)
      unless h.nil?
        # TODO: handle errors, at least path not found
        if h.status != 'Published'
          @html = File.open(h.path, 'r:UTF-8').read
        elsif h.manifestations.empty?
          head :bad_request
        else
          redirect_to url_for(controller: :manifestation, action: :read, id: h.manifestations[0].id)
        end
      else
        path = params[:path]
        path = '/' + path if path[0] != '/' # prepend slash if necessary
        if path =~ %r{/([^/]*)/?(index)?}
          d = HtmlDir.find_by_path(::Regexp.last_match(1))
          unless d.nil?
            unless d.person.nil?
              redirect_to url_for(controller: :authors, action: :toc, id: d.person.id)
            else
              @html = "<h1>#{t(:error)}</h1>"
            end
          end
        else
          @html = "<h1>#{t(:error)}</h1>"
        end
      end
    end
  end

  def render_html
    pp = params.permit(:id, :markdown, :genre, :add_person, :role, :comments, :remove_line_nums)
    @text = HtmlFile.find(pp[:id])
    if pp[:markdown].nil? && @text.markdown.nil?
      @markdown = File.open(@text.path + '.markdown', 'r:UTF-8').read
    else
      @markdown = pp[:markdown] || @text.markdown # TODO: make secure
      @text.update_markdown(@markdown.gsub('__________', '__SPLIT__')) # TODO: add locking of some sort to avoid concurrent overwrites
      @text.delete_pregen
      @text.genre = pp[:genre] if pp[:genre].present?
      @text.comments = pp[:comments]
      @markdown = @text.remove_line_nums! if pp[:remove_line_nums].present?
      if pp[:add_person].present?
        if pp[:role].to_i == HtmlFile::ROLE_AUTHOR
          @text.set_orig_author(pp[:add_person].to_i)
        else # translator
          @text.set_translator(pp[:add_person].to_i)
        end
      end
      @text.save
    end
    @html = MultiMarkdown.new(@markdown.gsub('__SPLIT__', '__________')).to_html.force_encoding('UTF-8') # TODO: figure out why to_html defaults to ASCII 8-bit
    @person_matches = match_person(@text.author_string)
  end

  def poetry
    @text = HtmlFile.find(params[:id])
    @text.paras_to_lines!
    @text.paras_condensed = true # running it again would lose stanzas!
    @text.save!
    redirect_to action: :render_html, id: params[:id]
  end

  def chop_title
    @text = HtmlFile.find(params[:id])
    markdown = File.open(@text.path + '.markdown', 'r:UTF-8').read # need to read the whole thing, to save it back
    lines = markdown.split "\n"
    title = lines.shift
    new_title = lines.shift while new_title !~ /\p{Word}/
    slashpos = new_title.index('/')
    slashpos = 0 if slashpos.nil?
    updated_title = new_title[0..slashpos - 1].strip
    unless slashpos.nil?
      title =~ %r{/}
      newbuf = '# ' + updated_title + ' /'
      newbuf += if ::Regexp.last_match.post_match.nil?
                  ' ' + @text.html_dir.person.name
                else
                  ::Regexp.last_match.post_match
                end
      newbuf += "\n" + lines.join("\n")
      File.binwrite(@text.path + '.markdown', newbuf) # write back
      flash[:notice] = t(:updated_successfully)
    else
      flash[:error] = t(:malformed_line)
    end
    redirect_to action: :render_html, id: params[:id]
  end

  def chop3
    chopN(3)
    redirect_to action: :render_html, id: params[:id]
  end

  def chop2
    chopN(2)
    redirect_to action: :render_html, id: params[:id]
  end

  def chop1
    chopN(1)
    redirect_to action: :render_html, id: params[:id]
  end

  def choplast1
    choplastN(1)
    redirect_to action: :render_html, id: params[:id]
  end

  def choplast2
    choplastN(2)
    redirect_to action: :render_html, id: params[:id]
  end

  # def metadata
  #  @text = HtmlFile.find(params[:id])
  #  @authors = @text.guess_authors
  # end
  def confirm_html_dir_person
    @text = HtmlFile.find(params[:id])
    @text.person = @text.html_dir.person
    @text.save!
    flash[:notice] = t(:confirmed_person_as_author, author: @text.person.name)
    render json: nil
  end

  protected

  def new_postprocess(buf)
    # join lines in <span> elements that, er, span more than one line
    buf.gsub!(%r{<span.*?>.*?\n.*?</span>}) { |thematch| thematch.sub("\n", ' ') }
    # remove all <span> tags because pandoc generates them excessively
    buf.gsub!(/<span.*?>/m, '')
    buf.gsub!('</span>', '')
    lines = buf.split("\n")
    in_footnotes = false
    prev_nikkud = false
    (0..lines.length - 1).each do |i|
      lines[i].strip!
      if lines[i].empty? and prev_nikkud
        lines[i] = '> '
        next
      end
      uniq_chars = lines[i].gsub(/[\s\u00a0]/, '').chars.uniq
      if [['*'], ["\u2013"]].include?(uniq_chars) # if the line only contains asterisks, or Unicode En-Dash (U+2013)
        lines[i] = '***' # make it a Markdown horizontal rule
        prev_nikkud = false
      else
        nikkud = is_full_nikkud(lines[i])
        in_footnotes = true if lines[i] =~ /^\[\^\d+\]:/ # once reached the footnotes section, set the footnotes mode to properly handle multiline footnotes with tabs
        if nikkud
          # make full-nikkud lines PRE
          lines[i] = '> ' + lines[i] unless lines[i] =~ /\[\^\d+/ # produce a blockquote (PRE would ignore bold and other markup)
          prev_nikkud = true
        else
          prev_nikkud = false
        end
        if in_footnotes && lines[i] !~ /^\[\^\d+\]:/ # add a tab for multiline footnotes
          lines[i] = "\t" + lines[i]
        end
      end
    end
    new_buffer = lines.join "\n"
    new_buffer.gsub!("\n\s*\n\s*\n", "\n\n")
    ['.', ',', ':', ';', '?', '!'].each do |c|
      new_buffer.gsub!(" #{c}", c) # remove spaces before punctuation
    end
    new_buffer.gsub!('©כל הזכויות', '© כל הזכויות') # fix an artifact of the conversion
    new_buffer.gsub!(/> (.*?)\n\s*\n\s*\n/, "> \\1\n\n<br>\n") # add <br> tags for poetry, as a workaround to preserve stanza breaks
    new_buffer.gsub!('&&STANZA&&', "\n> \n<br />\n> \n") # sigh
    new_buffer.gsub!('&amp;&amp;STANZA&amp;&amp;', "\n> \n<br />\n> \n") # sigh
    new_buffer.gsub!(%r{(\n\s*)*\n> \n<br />\n> (\n\s*)*}, "\n> \n<br />\n> \n\n") # sigh
    new_buffer.gsub!(/\n> *> +/, "\n> ") # we basically never want this super-large indented poetry
    new_buffer.gsub!(/\n\s*\n> *\n> /, "\n> \n> ") # remove extra newlines before verse lines
    new_buffer.gsub!('> <br />', '<br />') # remove PRE from line-break, which confuses the markdown processor
    new_buffer.gsub!('</div>', "</div>\n") # add newlines after divs
    return new_buffer
  end

  def render_from_markdown(htmlfile)
    markdown = File.open(htmlfile.path + '.markdown', 'r:UTF-8').read
    MultiMarkdown.new(markdown.gsub('__SPLIT__', '__________')).to_html.force_encoding('UTF-8') # TODO: figure out why to_html defaults to ASCII 8-bit
  end

  def choplastN(line_count)
    @text = HtmlFile.find(params[:id])
    @markdown = File.open(@text.path + '.markdown', 'r:UTF-8').read
    File.binwrite(@text.path + '.markdown', @markdown.split("\n")[0..-(line_count + 1)].join("\n"))
  end

  def chopN(line_count) # TODO: rewrite this weird mess
    @text = HtmlFile.find(params[:id])
    @markdown = File.open(@text.path + '.markdown', 'r:UTF-8').read
    lines = @markdown.split "\n"
    new_lines = []
    if lines[0] =~ /^#\s+/
      new_lines.push lines[0] # copy over our own generated title / author line
      lines.shift
    end
    while line_count > 0
      line = lines.shift
      if line.match(/\S/)
        line_count -= 1 # skip one non-empty line and decrement
      else
        new_lines.push line # preserve whitespace lines
      end
      next
    end
    new_lines += lines # just append the remaining lines
    @markdown = new_lines.join "\n"
    File.binwrite(@text.path + '.markdown', @markdown) # write back
  end

  private

  def hf_params
    params.require(:html_file)
          .permit(
            :title,
            :genre,
            :markdown,
            :publisher,
            :comments,
            :path,
            :url,
            :status,
            :orig_mtime,
            :orig_ctime,
            :author_id,
            :doc,
            :translator_id,
            :orig_lang,
            :year_published
          )
  end
end
