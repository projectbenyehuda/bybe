# Creates or overwrites downloadable from given Html file using provided file format
class MakeFreshDownloadable < ApplicationService
  # @return created Downloadable object
  def call(format, filename, html, download_entity, author_string, kwic_text: nil)
    html = images_to_absolute_url(html)
    dl = download_entity.downloadables.where(doctype: format).first
    if dl.nil?
      dl = Downloadable.new(doctype: format)
      download_entity.downloadables << dl
    end

    begin
      case format
      when 'pdf'
        html.gsub!(/<img src=.*?active_storage.*?>/) { |match| "<div style=\"width:209mm\">#{match}</div>" }
        html.sub!('</head>',
                  '<style>html, body {width: 20cm !important;} p{max-width: 20cm;} div {max-width:20cm;} img {max-width: 100%;}</style></head>')
        # html.sub!(/<body.*?>/, "#{$&}<div class=\"html-wrapper\" style=\"position:absolute\">")
        # html.sub!('</body>','</div></body>')
        pdfname = HtmlFile.pdf_from_any_html(html)
        dl.stored_file.attach(io: File.open(pdfname), filename: filename)
        File.delete(pdfname) # delete temporary generated PDF
      when 'docx'
        begin
          temp_file = Tempfile.new('tmp_doc_' + download_entity.id.to_s, 'tmp/')
          temp_file.puts(PandocRuby.convert(html, M: 'dir=rtl', from: :html, to: :docx).force_encoding('UTF-8')) # requires pandoc 1.17.3 or higher, for correct directionality
          temp_file.chmod(0o644)
          temp_file.rewind
          dl.stored_file.attach(io: temp_file, filename: filename)
        ensure
          temp_file.close
        end
      when 'odt'
        begin
          temp_file = Tempfile.new('tmp_doc_' + download_entity.id.to_s, 'tmp/')
          temp_file.puts(PandocRuby.convert(html, M: 'dir=rtl', from: :html, to: :odt).force_encoding('UTF-8')) # requires pandoc 1.17.3 or higher, for correct directionality
          temp_file.chmod(0o644)
          temp_file.rewind
          dl.stored_file.attach(io: temp_file, filename: filename)
        ensure
          temp_file.close
        end
      when 'html'
        begin
          temp_file = Tempfile.new('tmp_html_' + download_entity.id.to_s, 'tmp/')
          temp_file.puts(html)
          temp_file.chmod(0o644)
          temp_file.rewind
          dl.stored_file.attach(io: temp_file, filename: filename)
        ensure
          temp_file.close
        end
      when 'txt'
        txt = html2txt(html)
        txt.gsub!("\n", "\r\n") # windows linebreaks
        begin
          temp_file = Tempfile.new('tmp_txt_' + download_entity.id.to_s, 'tmp/')
          temp_file.puts(txt)
          temp_file.chmod(0o644)
          temp_file.rewind
          dl.stored_file.attach(io: temp_file, filename: filename)
        ensure
          temp_file.close
        end
      when 'epub'
        begin
          epubname = make_epub_from_single_html(html, download_entity, author_string)
          dl.stored_file.attach(io: File.open(epubname), filename: filename)
          File.delete(epubname) # delete temporary generated EPUB
        end
      when 'mobi'
        begin
          # TODO: figure out how not to go through epub
          epubname = make_epub_from_single_html(html, download_entity, author_string)
          mobiname = epubname[epubname.rindex('/') + 1..-6] + '.mobi'
          out = `kindlegen #{epubname} -c1 -o #{mobiname}`
          mobiname = epubname[0..-6] + '.mobi'
          dl.stored_file.attach(io: File.open(mobiname), filename: filename)
          File.delete(epubname) # delete temporary generated EPUB
          File.delete(mobiname) # delete temporary generated MOBI
        end
      when 'kwic'
        raise ArgumentError, 'KWIC format requires kwic_text parameter' if kwic_text.nil?

        kwic_text.gsub!("\n", "\r\n") # windows linebreaks
        begin
          temp_file = Tempfile.new('tmp_kwic_' + download_entity.id.to_s, 'tmp/')
          temp_file.puts(kwic_text)
          temp_file.chmod(0o644)
          temp_file.rewind
          dl.stored_file.attach(io: temp_file, filename: filename)
        ensure
          temp_file.close
        end
      else
        raise I18n.t(:unrecognized_format)
      end

      # Verify the attachment was successful
      unless dl.stored_file.attached?
        dl.destroy
        raise StandardError, "Failed to attach file to Downloadable for #{download_entity.class.name} #{download_entity.id}"
      end
    rescue => e
      # If something went wrong, destroy the downloadable record
      dl.destroy if dl.persisted?
      raise e
    end

    return dl
  end

  private

  def images_to_absolute_url(buf)
    return buf.gsub('<img src="/rails/active_storage',
                    "<img src=\"#{Rails.application.routes.url_helpers.root_url}/rails/active_storage")
  end
end
