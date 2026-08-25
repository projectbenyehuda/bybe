# frozen_string_literal: true

module Converters
  class Html2Pdf < ApplicationService
    # Converts HTML to PDF using the Chromium browser. Result is written to the output_file.
    # Result is written to the output_file.
    # @param html [String] The HTML content to convert
    # @param output_file [File] file representing the output PDF file (must be open in write mode)
    def call(html, output_file)
      # TODO: implement
    end
  end
end