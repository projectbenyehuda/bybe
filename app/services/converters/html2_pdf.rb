# frozen_string_literal: true

require 'open3'

module Converters
  # Converts HTML string to PDF using the Chromium browser.
  class Html2Pdf < ApplicationService
    # Converts HTML to PDF using the Chromium browser. Result is written to the output_file.
    # @param html [String] The HTML content to convert
    # @param output_file [File] file representing the output PDF file (must be open in write mode)
    # @return [Boolean] true on success, false on failure
    def call(html, output_file)
      # Use Rails.root/tmp rather than /tmp so that both this process and chromium
      # resolve the same real filesystem path. Using /tmp can fail when the Rails
      # process runs under a systemd unit with PrivateTmp=true (or chromium runs as
      # a snap), because each process sees a different /tmp namespace.
      tmp_dir = Rails.root.join('tmp').to_s
      tmpfile = Tempfile.new(['html2pdf__', '.html'], tmp_dir)
      pdffilename = "#{tmpfile.path}.pdf"
      begin
        tmpfile.write(html)
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
        output_file.binmode
        output_file.write(File.binread(pdffilename))
        output_file.flush
      rescue StandardError => e
        Rails.logger.error("[Converters::Html2Pdf] #{e.class}: #{e.message}")
        return false
      ensure
        tmpfile.close!
        FileUtils.rm_f(pdffilename)
      end
      true
    end
  end
end
