# frozen_string_literal: true

require 'open3'

module Converters
  # Converts HTML string to PDF using the Chromium browser.
  class Html2Pdf < ApplicationService
    # Converts HTML to PDF using the Chromium browser. Result is saved to output_path.
    # @param html [String] The HTML content to convert
    # @param output_path [String] path where the resulting PDF file should be saved
    # @return [Boolean] true on success, false on failure
    def call(html, output_path)
      # Use Rails.root/tmp rather than /tmp so that both this process and chromium
      # resolve the same real filesystem path. Using /tmp can fail when the Rails
      # process runs under a systemd unit with PrivateTmp=true (or chromium runs as
      # a snap), because each process sees a different /tmp namespace.
      tmp_dir = Rails.root.join('tmp').to_s
      tmpfile = Tempfile.new(['html2pdf__', '.html'], tmp_dir)
      pdffilename = "#{tmpfile.path}.pdf"
      begin
        tmpfile.write(prepare_html(html))
        tmpfile.flush
        args = ['chromium', '--headless', '--disable-gpu',
                "--print-to-pdf=#{pdffilename}", '--no-pdf-header-footer',
                "file://#{tmpfile.path}"]
        args.insert(1, '--no-sandbox') if Process.uid.zero? || ENV['CHROME_NO_SANDBOX'] == '1'
        sandbox = args.include?('--no-sandbox') ? 'off' : 'on'
        Rails.logger.info("[Converters::Html2Pdf] uid=#{Process.uid} sandbox=#{sandbox}")
        Rails.logger.info("[Converters::Html2Pdf] Running: #{args.join(' ')}")
        stdout, stderr, status = Open3.capture3(*args)
        pdf_exists = File.exist?(pdffilename)
        Rails.logger.info("[Converters::Html2Pdf] exit_status=#{status.exitstatus.inspect} pdf_exists=#{pdf_exists}")
        Rails.logger.info("[Converters::Html2Pdf] stdout: #{stdout}") if stdout.present?
        Rails.logger.info("[Converters::Html2Pdf] stderr: #{stderr}") if stderr.present?
        unless status.success? && pdf_exists
          Rails.logger.error(
            '[Converters::Html2Pdf] Chrome PDF generation failed. ' \
            "exit_status=#{status.exitstatus.inspect} pdf_exists=#{pdf_exists}"
          )
          return false
        end
        FileUtils.mv(pdffilename, output_path)
      rescue StandardError => e
        Rails.logger.error("[Converters::Html2Pdf] #{e.class}: #{e.message}")
        return false
      ensure
        tmpfile.close!
        FileUtils.rm_f(pdffilename)
      end
      true
    end

    PDF_CSS = '@page {size: A4; margin: 2cm;} img {max-width: 100%; height: auto;}'

    private

    # Wraps an HTML fragment (or full document) in a print-ready full document
    # with A4 page CSS and ActiveStorage image scaling.
    def prepare_html(html)
      html = html.gsub(/<img src=.*?active_storage.*?>/) { |match| "<div style=\"max-width:100%\">#{match}</div>" }
      if html.include?('</head>')
        html.sub('</head>', "<style>#{PDF_CSS}</style></head>")
      else
        "<!DOCTYPE html><html><head><meta charset='utf-8'><style>#{PDF_CSS}</style></head>" \
          "<body dir='rtl'>#{html}</body></html>"
      end
    end
  end
end
