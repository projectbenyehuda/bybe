# frozen_string_literal: true

# service to convert HTML snippet to MultiMarkdown
class HtmlToMarkdown < ApplicationService
  def call(html)
    return '' if html.blank?

    PandocRuby.convert(
      html.strip
          .gsub(%r{<br\s*/?>\n?\s*(?:&nbsp;|\u00A0)+}i, '</p><p>')
          .gsub(/\u00A0|&nbsp;/, ' '),
      M: 'dir=rtl',
      from: :html,
      to: 'markdown_mmd-pipe_tables+raw_html'
    ).force_encoding('UTF-8')
     .gsub(/^(\d+)\. /, "\\1\\\\. ")
  end
end
